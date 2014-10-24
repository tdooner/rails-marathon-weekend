name 'mesos_slave'

run_list %w[
  docker
  mesos_wrapper::slave
  mesos_wrapper::marathon
  chef-client::service
]
