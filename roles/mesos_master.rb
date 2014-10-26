name 'mesos_master'

default_attributes(
  # XXX: In a world where the entire cluster isn't restarted all the time, this
  # should be 'server'
  'consul' => { 'service_mode' => 'bootstrap' }
)

run_list %w[
  mesos_wrapper::master
  consul_wrapper
  chef-client::service
]
