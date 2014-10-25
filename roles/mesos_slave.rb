name 'mesos_slave'

default_attributes(
  'consul' => { 'service_mode' => 'client' }
)

run_list %w[
  docker
  mesos_wrapper::slave
  mesos_wrapper::marathon
  consul_wrapper
  chef-client::service
]
