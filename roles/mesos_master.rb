name 'mesos_master'

run_list %w[
  mesos_wrapper::mesosphere
  mesos_wrapper::master
]
