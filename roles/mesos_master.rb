name 'mesos_master'

run_list %w[
  mesos_wrapper::master
  chef-client::service
]
