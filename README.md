# Mesos, Marathon, and Rails

This was a weekend experiment to see how easy or hard it would be to create a Mesos cluster in AWS, and deploy a Rails app to that cluster (spoiler alert: not too hard).

Overall, I'm pretty impressed with how easy everything was to configure–in no small part due to Zookeeper handling all the Mesos/Marathon configuration and Chef doing the basic service discovery needed to get Marathon up-and-running.

Overall, this ties together the following technologies:
* Mesos
* Marathon
* Consul
* consul-template / HAProxy
* Chef

The goals of my weekend project were:

1. Run Rails on Mesos using Docker
2. Create a system which can be scaled up and down easily
3. Use a load-balancing approach which is suitable for a publicly-facing web application

## Starting Off Simple (v1) Architecture

It took me about 4 hours to get a Mesos Cluster up-and-running, and most of that was spend on installing Chef and getting my local workstation set up.

I initially attempted a simple architecture, knowing that it wouldn't accomplish goal #3 (have a  production-ready load balancing architecture): *run one copy of the Rails app per marathon node.*

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

This seems ripe for our use case. It is easy to add new services (`PUT /v1/agent/service/register`) and manage them once they are added.

##
The architecture for this looks something like:

![](https://docs.google.com/drawings/d/1B_uVfwYkwrHFSC0TkT-L2iuco9eFACncn1QuT-xhUDQ/pub?w=535&h=353&)
