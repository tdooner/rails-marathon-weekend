%w[ruby ruby-sinatra].each do |package_name|
  package package_name do
    action :install
  end
end

cookbook_file '/usr/local/bin/ruby-configure-consul' do
  source 'app.rb'
  mode 0755
  owner 'root'
  group 'root'

  notifies :restart, 'service[ruby-configure-consul]'
end

template '/etc/init/ruby-configure-consul.conf' do
  variables({
    script_path: '/usr/local/bin/ruby-configure-consul',
    env: {
      RACK_ENV: 'production', # so sinatra listens on 0.0.0.0
      MARATHON_URL_BASE: 'http://0.0.0.0:8080', # todo: use the attributes for
      CONSUL_URL_BASE: 'http://0.0.0.0:8500',   #       these port numbers
    }
  })

  notifies :restart, 'service[ruby-configure-consul]'
end

service 'ruby-configure-consul' do
  provider Chef::Provider::Service::Upstart
  action [:enable, :start]
end
