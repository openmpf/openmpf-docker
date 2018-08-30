# Deploying OpenMPF With Docker Swarm

## Prerequisites
- A cluster of machine running the docker daemon.

- The client and daemon API must both be at least 1.24 to use this command.
Use the `docker version` command on the client to check your client and daemon
API versions.

- A Docker registry that is accessible by each machine that you plan to join to
the swarm. There are many offering for docker registries. Including public
cloud-hosted registries, private cloud-hosted registries, or self-hosted
registries. Feel free to pick the solution that works best for you, but please
note that if you choose to host any images on a public registry, you accept
responsibility for the usage of those images.

## Set Up The Swarm Cluster

### Initialize the swarm on the docker machine that you wish to act as the manager node.

This manager node is where you will be able to deploy and manager the stack
from.
- `docker stack init`

### Join the other nodes to the swarm cluster.
After you run swarm init, you should see an output that looks like the follow.
Copy that command and run it on each machine that you want to be a part of the
cluster.
`docker swarm join \
    --token <token> \
    <manager ip address>:2377`

## Build and Push The Images

### Build the images using this repository.
Next you can build the OpenMPF Docker images on the machine that you cloned
this repository on.
If you have not already done so, see the "Install and Configure Docker"
in the [README](README.md) for information on how to prepare the project to be
build. Note that you only do this once since you will be pushing the images to a
central repository.
`docker-compose build`

### Login to the repository.
`docker login`

** IMPORTANT the tag must match the tag that is used in the swarm-compose.yml
file. The naming convention is as follows:
<repository_address>:5000/<user>/<image_name>:latest

- `docker tag` (follow how they look in swarm-compose.yml fie)

- change the image names in swarm-compose.yml file.

- `docker-compose -f swarm-compose.yml push` \
    (if registry is specified in compose file)

## Deploy To the Swarm

### Setup up a volume driver to keep the volumes in sync between swarm nodes.

In order for Docker Swarm to keep a synchronized volume between the nodes in the
swarm, it needs a 3rd party volume driver. One of the simplest ways to do this
is to utilize NFS. If your network configuration does not support NFS, or if
you would like to make use of a cloud provider's storage solution, then there
are many other volume drivers that you can explore (i.e. REX-Ray).
This guide will be showing how to do a deployment with NFS.
- `docker volume create --driver local --opt type=nfs --opt o=addr=<address of \
file share server>,rw --opt device=:<path to mounted share> \
<stack name>_<name of volume>`

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
