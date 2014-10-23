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
  result = connection.servers.all('tag-value' => h[:tag], 'instance-state-name' => 'stopped')
  servers += result
  puts "  found #{result.length} stopped #{h[:name]} instances"
end

stop = 'n'
puts 'Start them now? (y/n): '

if gets.chomp == 'y'
  servers.each do |server|
    puts "Starting server #{server.id}..."
    server.start
  end
end
