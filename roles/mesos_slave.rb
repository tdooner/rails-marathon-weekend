name 'mesos_slave'

run_list %w[
  mesos_wrapper::slave
  chef-client::service
]
