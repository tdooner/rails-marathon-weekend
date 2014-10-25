node.default['consul']['servers'] = search(:node, 'role:mesos_master').map(&:ipaddress)

include_recipe 'consul_wrapper::_configure_consul_script'

include_recipe 'consul'
