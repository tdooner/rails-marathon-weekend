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

tags = [
  { tag: 'Mesos-Chef-Server', name: 'Chef Server' },
  { tag: 'Mesos-Master', name: 'Mesos Master' },
  { tag: 'Mesos-Slave', name: 'Mesos Slave' },
]

servers = []

tags.each do |h|
  result = connection.servers.all('tag-value' => h[:tag], 'instance-state-name' => 'running')
  servers += result
  puts "  found #{result.length} running #{h[:name]} instances"
end

stop = 'n'
puts 'Shut down now? (y/n): '

if gets.chomp == 'y'
  servers.each do |server|
    puts "Stopping server #{server.id}..."
    server.stop
  end
end
