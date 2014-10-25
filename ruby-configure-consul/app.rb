#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'uri'
require 'net/http'

ENV['MARATHON_URL_BASE'] ||= 'http://0.0.0.0:8080'
ENV['CONSUL_URL_BASE'] ||= 'http://0.0.0.0:8500'

helpers do
  def get_alive_local_marathon_tasks
    marathon_url = URI("#{ENV['MARATHON_URL_BASE']}/v2/apps/rails-marathon-test/tasks")
    marathon_resp = JSON.parse(Net::HTTP.start(marathon_url.host, marathon_url.port) do |http|
      req = Net::HTTP::Get.new(marathon_url.request_uri)
      req['Accept'] = 'application/json'
      resp = http.request req
      puts resp.body

      resp.body
    end)

    fqdn = Socket.gethostbyname(Socket.gethostname).first

    marathon_resp['tasks'].keep_if do |task|
      task['healthCheckResults'].first['alive'] && task['host'] == fqdn
    end
  end

  def create_consul_services(tasks)
    consul_url = URI("#{ENV['CONSUL_URL_BASE']}/v1/agent/service/register")

    Net::HTTP.start(consul_url.host, consul_url.port) do |http|
      url = URI("#{ENV['CONSUL_URL_BASE']}/v1/agent/services")
      existing_req = Net::HTTP::Get.new url.request_uri
      existing = JSON.parse(http.request(existing_req).body)

      # Create services in consul for each marathon task:
      tasks.each do |task|
        name, id = task['id'].split('.')
        service = {
          'ID' => id,
          'Name' => name,
          'Port' => task['ports'].first,
        }
        next if existing.delete(id)

        req = Net::HTTP::Put.new consul_url.request_uri
        req.body = service.to_json
        puts "adding service: #{service}"
        http.request req
      end

      # Remove existing services from Consul that no longer are in marathon:
      existing.each do |id, _details|
        url = URI("#{ENV['CONSUL_URL_BASE']}/v1/agent/service/deregister/#{id}")
        req = Net::HTTP::Get.new url.request_uri
        puts "removing service: #{id}"

        http.request(req)
      end
    end
  end
end

post '/' do
  create_consul_services(get_alive_local_marathon_tasks)
  true
end
