package 'marathon'

directory '/etc/marathon/conf' do
  action :create
  recursive true
end

file '/etc/marathon/conf/event_subscriber' do
  content 'http_callback'
end

file '/etc/marathon/conf/http_endpoints' do
  content 'http://0.0.0.0:4567/'
end

service 'marathon' do
  action [:enable, :start]
end
