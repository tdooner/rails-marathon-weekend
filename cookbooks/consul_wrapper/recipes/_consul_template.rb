config_template_path = '/etc/haproxy/haproxy.cfg.ctmpl'

cookbook_file config_template_path do
  action :create
end

ark 'consul-template' do
  url 'https://github.com/hashicorp/consul-template/releases/download/v0.1.0/consul-template_0.1.0_linux_amd64.tar.gz'
  has_binaries ['consul-template']
  path '/usr/local/bin'
  action :put
end

template '/etc/init/consul-template.conf' do    # yo dawg, I heard you like templates.
  variables({
    consul_path: '0.0.0.0:8500', # todo: use attributes for this?
    template: "#{config_template_path}:#{node['haproxy']['conf_dir']}/haproxy.cfg:service haproxy reload"
  })
end

service 'consul-template' do
  provider Chef::Provider::Service::Upstart
  action [:enable, :start]
end
