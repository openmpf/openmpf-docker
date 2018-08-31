# Deploying OpenMPF with Docker Swarm

## Do I need Swarm Deployment?

If you would like to run OpenMPF across multiple physical or virtual machines
then we recommend following this guide to setup a
[Docker Swarm](https://docs.docker.com/engine/swarm/) deployment. Instead, if
you would like to run OpenMPF on one machine, for example, to quickly test out
the software, then we recommend running `docker compose up` as explained in the
[README](README.md).

## Prerequisites

- A cluster of machines running the docker daemon. The client and daemon
(server) API must both be at least 1.24. Use the `docker version` command to
check your client and daemon API versions. See the [Install and Configure
Docker](README.md#install-and-configure-docker) section in the README.

- A [Docker registry](https://docs.docker.com/registry/) that is accessible by
each machine that you plan to join to
the swarm. There are many offerings for docker registries, including public
cloud-hosted registries, such as [Docker Hub](https://hub.docker.com/),
private cloud-hosted registries, or
[self-hosted registries](https://github.com/docker/distribution).
Feel free to pick the solution that works best for you, but please note that if
you choose to host any images on a public registry, you accept responsibility
for the usage of those images.

## Set Up The Swarm Cluster

### Initialize the Swarm Cluster

Choose a machine that you wish to act as the manager node. You will be able to
deploy and manager the stack from this node. Run the following command on that
node:
- `docker stack init`

### Join other machines to the Swarm Cluster

After you run init command above, you should see an output that looks like the
following:

```
docker swarm join
    --token <token>
    <manager ip address>:2377
```

Copy that command and run it on each machine that you want to be a part of the
swarm cluster.

## Build and Push the OpenMPF Docker Images

If you have not already done so, build the OpenMPF Docker images on the machine
that you used to clone the openmpf-docker repository by following the
steps in the [Build the OpenMPF Docker Images](README.md#build-the-openmpf-docker-images)
section in the README.

Log into the Docker registry:

- `docker login <server>:<port>`

Note that the `<server>:<port>` part is optional. If omitted, you will try to
log into the [Docker Hub](https://hub.docker.com/). Use the appropriate server hostname and port number for your Docker registry.

Next, tag the images you built:

- `docker tag openmpf_active_mq <server>:<port>/<user>/openmpf_active_mq:latest`
- `docker tag openmpf_docker_workflow_manager <server>:<port>/<user>/openmpf_docker_workflow_manager:latest`
- `docker tag openmpf_docker_node_manager <server>:<port>/<user>/openmpf_docker_node_manager:latest`

Use the appropriate server hostname, port number, and username for your Docker registry.

Change the image names in the swarm-compose.yml file to match your tags.

Next, push the images to the Docker registry:

- `docker-compose -f swarm-compose.yml push`

## Deploy to the Swarm Cluster

### Setup up a volume driver to keep the volumes in sync between swarm nodes.

In order for Docker Swarm to keep a synchronized volume between the nodes in the
swarm, it needs a 3rd party volume driver. One of the simplest ways to do this
is to utilize NFS. If your network configuration does not support NFS, or if
you would like to make use of a cloud provider's storage solution, then there
are many other volume drivers that you can explore (i.e. REX-Ray).
This guide will be showing how to do a deployment with NFS.
- `docker volume create --driver local --opt type=nfs --opt o=addr=<address of \
file share server>,rw --opt device=:<path to mounted share> \
mpf_mpf-data`

### Deploy the stack to the swarm and watch the services come up.

- `docker stack deploy -c swarm-compose.yml mpf --with-registry-auth`

That stack will likely take long time to come up the first time you deploy it
because if a container gets scheduled on a node where the image is not present
it needs to download the image from the docker registry, which takes some time.
This will be much faster later one once the images are downloaded on the nodes.
If the images are updated, only the changes are downloaded from the docker
registry.

- Log in to the workflow manager and add the nodes in the Nodes page.

You can reach the workflow manager with the url and port 8080 of any of the
nodes in the swarm. The request will be forwarded to the node that is hosting
the workflow manager container.

Once you have logged in, go to the Nodes page and add all of the nodes. You
should see that they each end in a unique ID. That number corresponds to the
ID of the container. The number of node manager containers that come up is
determined by the `replicas:` in the swarm-compose file, feel free to change it
if you please.

- Monitoring the services from swarm.

A couple useful commands for monitoring the services are:

-- `docker service ls`
-- `docker stack ps mpf`
-- `docker ps` to show what services are running on that node
