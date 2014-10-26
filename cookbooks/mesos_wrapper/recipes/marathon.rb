# This is my take at writing a cookbook for this instead of using the upstream
# one.

package 'marathon'

file '/etc/init.d/marathon' do
  action :delete
end

directory '/etc/marathon/conf' do
  action :create
  recursive true
end

file '/etc/marathon/conf/event_subscriber' do
  content 'http_callback'
  notifies :restart, 'service[marathon]'
end

file '/etc/marathon/conf/http_endpoints' do
  content "http://#{node['fqdn']}:4567/"
  notifies :restart, 'service[marathon]'
end

service 'marathon' do
  provider Chef::Provider::Service::Upstart
  action [:enable, :start]
end
