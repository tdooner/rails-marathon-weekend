include_recipe 'haproxy::manual'

chef_gem 'chef-rewind'
require 'chef/rewind'
unwind 'haproxy_config[Create haproxy.cfg]'
