#!/usr/bin/env ruby
require 'chef/knife'
require 'fog'

Chef::Config.from_file('.chef/knife.rb')

connection = Fog::Compute.new(
  provider: 'AWS',
  region: 'us-east-1',
  aws_access_key_id: Chef::Config[:knife][:aws_access_key_id],
  aws_secret_access_key: Chef::Config[:knife][:aws_secret_access_key],
)

puts 'Finding servers...'

tags = {
  'Mesos-Chef-Server' => { name: 'Chef Server' },
  'Mesos-Master' => { name: 'Mesos Master', run_chef: true },
  'Mesos-Slave' => { name: 'Mesos Slave', run_chef: true },
}

servers = []

tags.each do |tag, h|
  result = connection.servers.all('tag-value' => tag, 'instance-state-name' => 'stopped')
  servers += result
  puts "  found #{result.length} stopped #{h[:name]} instances"
end

$stdout.write 'Start them now? (y/n): '

if gets.chomp == 'y'
  puts "\n"

  servers.each do |server|
    puts "Starting server #{server.id}..."
    server.start
  end

  servers.each do |server|
    next unless tags[server.tags['Name']][:run_chef]

    puts "Running Chef on server: #{server.tags['Name']}"

    server.wait_for(60) do |s|
      $stdout.write '.'
      can_ssh = Proc.new do
        begin
          Timeout.timeout(1) do
            TCPSocket.new(server.public_ip_address, 22).close
            true
          end
        rescue
          false
        end
      end

      s.state == 'running' && can_ssh.call
    end

    Net::SSH.start(server.public_ip_address, 'ubuntu') do |ssh|
      puts ssh.exec!('sudo chef-client 2>&1 >/dev/null')
    end
  end
end
