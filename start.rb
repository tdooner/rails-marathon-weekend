#!/usr/bin/env ruby
require 'chef/knife'
require 'fog'

Chef::Config.from_file('.chef/knife.rb')

# TODO Switch to AWS because they are cooler and will let me turn my servers
# off.

connection = Fog::Compute.new(
  provider: 'Rackspace',
  rackspace_username: Chef::Config[:rackspace_api_username],
  rackspace_api_key: Chef::Config[:rackspace_api_key],
  rackspace_region: Chef::Config[:rackspace_region],
)

chef_server = connection.servers.get('8b57cb28-5156-4e33-92b1-7a8050168cd8')
