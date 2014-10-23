master_ip = search(:node, 'role:mesos_master').first.ipaddress

node.default['mesos']['slave']['master'] = "zk://#{master_ip}:2181/mesos"

include_recipe 'mesos::slave'
