name 'mesos_master'

default_attributes(
  'consul' => { 'service_mode' => 'server' }
)

run_list %w[
  mesos_wrapper::master
  consul_wrapper
  chef-client::service
]
