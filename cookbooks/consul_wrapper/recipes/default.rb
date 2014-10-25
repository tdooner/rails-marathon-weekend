node.default['consul']['servers'] = search(:node, 'role:mesos_master').map(&:ipaddress)

include_recipe 'consul'
