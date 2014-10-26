node.default['consul']['servers'] = search(:node, 'role:mesos_master').map(&:ipaddress)

# Only do the haproxy / consul template stuff on the consul agents (and not the
# consul server) for now.
if node['consul']['service_mode'] == 'client'
  include_recipe 'consul_wrapper::_configure_consul_script'
  include_recipe 'consul_wrapper::_consul_template'
end

include_recipe 'consul'
