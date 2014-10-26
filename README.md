# Mesos, Marathon, and Rails

This was a weekend experiment to see how easy or hard it would be to create a Mesos cluster in AWS, and deploy a Rails app to that cluster (spoiler alert: not too hard).

The goals of my weekend project were:

1. Run Rails on Mesos using Docker
2. Create a system which can be scaled up and down easily
3. Use a load-balancing approach which is suitable for a publicly-facing web application

Overall, I'm pretty impressed with how easy everything was to configure–in no small part due to Zookeeper handling all the Mesos/Marathon configuration and Chef doing the basic service discovery needed to get Marathon up-and-running. And, the decision to run Rails turned out to be completely insignificant–anything that can be run in Docker would work equally well (I just chose Rails because that's what I do at my weekday job at [Brigade](https://github.com/brigade).)

Overall, this ties together the following technologies:
* [Apache Mesos](http://mesos.apache.org/)
* Mesosphere's [Marathon](https://mesosphere.github.io/marathon/)
* [Consul](https://consul.io/)
* [consul-template](https://github.com/hashicorp/consul-template) / HAProxy
* [Chef](https://www.getchef.com)

The fact that I could stand up an architecture like this in a weekend (and with less than $12 in EC2 resources) is amazing to me. These projects work very well together, and the level of server automation available today is excellent. But anyway, I digress...

## Marathon

Before diving in too deep, let me briefly describe Marathon.

Apache Mesos is a cluster scheduler but the APIs it provides to schedule frameworks are too raw for lazy web developers like myself who are just trying to run a web server. Fortunately, there are many pre-built [Mesos Frameworks](http://mesos.apache.org/documentation/latest/mesos-frameworks/) which provide simple configuration for scheduling long-running tasks like web servers.

[Singularity](https://github.com/HubSpot/Singularity) and [Aurora](http://aurora.incubator.apache.org/documentation/latest/) are two other Mesos frameworks in this space, but Marathon seemed like it would be the easiest to install (since it's also made/packaged by Mesosphere) and that it doesn't try to do too much.

Marathon manages "deployments" of "applications" that have multiple "tasks" running on different mesos slaves. For now I only have one application–my Rails app. **Marathon makes it easy to scale the number of tasks** running, so that is a good fit for my goals.

Also, **Marathon allows "Event Subscribers"** to receive HTTP callbacks•• when the state of the cluster changes. This flexibility will help with goal #3 (have a  production-ready load balancing architecture).

## Starting Off Simple (v1) Architecture

It took me about 4 hours to get a Mesos Cluster up-and-running (most of that was spend on installing Chef and getting my local workstation set up). I initially attempted a simple architecture, knowing that it wouldn't accomplish the load balancing goal: **run one copy of the Rails app per marathon node.**

The architecture looked like this: 

![](https://docs.google.com/drawings/d/1iiYQuqbF9ewBfOCqft5Im5CjVZuyjxuhnLWTpzUBFyk/pub?w=485&h=233)

Each Docker container was forwarding external port 80 to the container's port 3000, where Rails was running. A manually-configured Elastic Load Balancer in front distributed traffic between all the Mesos slaves.

The first snag was a big, unfortunate one: **AWS's Elastic Load Balancers cannot load balance to different ports on different instances** (nor a single instance multiple times on multiple ports). This disappointed me, because Rackspace has this functionality, and it would dramatically simplify the process to just register each Docker container in the load balancer separate, and rely on graceful shutdowns and health checks to prevent lost traffic.

But *c'est la vie*. It looks like we'll need to add another load balancing layer in order to run multiple containers on a given host...

#### ...Enter HAProxy

HAProxy fits the bill, is easy to configure, and has become the *de facto* client-side load balancer because of projects like [Airbnb's SmartStack](http://nerds.airbnb.com/smartstack-service-discovery-cloud/). This use-case is a bit unique, however: **we want HAProxy to only load balance between services running on *its* mesos slave**.

This might be technically possible with SmartStack (though no solution comes to mind...), but we use SmartStack at [Brigade](http://github.com/brigade) and this is a good excuse to *Think Different*™.

#### ...Enter Consul

Consul is a relatively new technology made by the Hashicorp folks to be a Swiss Army Knife of service discovery. Sporting both a DNS and HTTP API, Consul keeps your service definitions in-sync using a agent process which performs health checks and shares results with other agents via a intra-datacenter gossip protocol.

This seems ripe for our use case. It is easy to add new services (`PUT /v1/agent/service/register`) and manage them once they are added. This means we can write a [relatively simple daemon](https://github.com/tdooner/tom-mesos/blob/master/ruby-configure-consul/app.rb) that updates Consul whenever the Marathon state changes. (This script receives Marathon's event subscriber HTTP callbacks.)

The last piece is that we need the local HAProxy to be reconfigured when Consul services are added or removed. A new hashicorp micro-project [consul-template](https://github.com/hashicorp/consul-template) provides precisely this functionality. The daemon watches for changes in consul, re-renders [the haproxy config](https://github.com/tdooner/tom-mesos/blob/master/cookbooks/consul_wrapper/templates/default/haproxy.cfg.ctmpl.erb), and reloads haproxy. It doesn't use the haproxy stats socket as SmartStack does, but that is an optimization that could be added with a separate script.

There was just one last bump: **consul will return *all* nodes in a datacenter by default**. We don't want traffic that has already been load-balanced to a Mesos Slave to again traverse the network. As a hack to get around this, I tagged each service with the FQDN (well, `fqdn.gsub(/\./, '-')`) and used that tag in the haproxy consul-template template. [It just works!](https://www.youtube.com/watch?v=qmPq00jelpc)!

So, that brings us to the Sunday-afternoon architecture:

## "Basically there" (v2) Architecture

![](https://docs.google.com/drawings/d/1B_uVfwYkwrHFSC0TkT-L2iuco9eFACncn1QuT-xhUDQ/pub?w=802&h=530)

I still have some testing to do, but this seems to be working pretty well and resilient to slaves coming into and out of the cluster.

# Lessons Learned
* Marathon
  1. **Only the master dispatches HTTP webhooks.** In hindsight this should have been obvious, but it is not documented anywhere. So, every marathon client needs to be started with its network-accessible IP address as a value for [`http_endpoints`](https://mesosphere.github.io/marathon/docs/event-bus.html)
  2. **Marathon Error messages don't exist.** It's a still relatively new project, but trying to debug why certain behavior is happening in the web UI is quite difficult.
  3. **`docker pull` takes a long time**. The first time I try to scale onto a new mesos slave, the marathon task times out because Docker is fetching ~1 GB of images. I'm not sure if there is a current way to get around this.
* Consul
  1. In this toy architecture, *bootstrap mode* is your friend because you can reboot the singular master with impunity. But in a real architecture, you probably would not want to reboot the master and thus not run in bootstrap mode.

# Running For Yourself
If you want to try this yourself, you'll have to follow (something like) the following steps:

```bash
# install ruby and system dependencies
brew install rbenv ruby-build jq
rbenv install 1.9.3-p327        # or whatever. this is closest to ubuntu 14.04's packaged version

# install ruby libraries
gem install knife berkshelf knife-ec2

# create a chef server on EC2. give it a static IP or you'll be sad later.
# https://www.getchef.com/download-open-source-chef-server-11/
# You'll need to get the validation key from /etc/chef-server/ on your server and put it into
# .chef in this directory

# create local chef configuration
mkdir .chef
echo <<-CHEF_CONFIG > .chef/knife.rb
knife[:aws_access_key_id] = '[your access key id]'
knife[:aws_secret_access_key] = '[your secret access key]'

chef_server_url 'https://[your chef server]'
node_name '[your chef username]'
client_key '[your chef client.pem]'
validation_key '[your chef validator.pem]'
CHEF_CONFIG

# done!
```
Here are the random scripts that exist in this directory:
* To spawn a mesos master: `./create_master.sh`.
* To spawn a mesos slave: `./create_slave.sh`.
* To shut everything down: `ruby stop.rb`.
* To start everything: `ruby start.rb`.
