# Deploying OpenMPF with Docker Swarm

## Do I need Swarm Deployment?

If you would like to run OpenMPF across multiple physical or virtual machines
then we recommend following this guide to setup a
[Docker Swarm](https://docs.docker.com/engine/swarm/) deployment. Instead, if
you would like to run OpenMPF on one machine, for example, to quickly test out
the software, then we recommend running `docker compose up` as explained in the
[README](README.md).

## Prerequisites

- A cluster of machines running the Docker daemon. The client and daemon
(server) API must both be at least 1.24. Use the `docker version` command to
check your client and daemon API versions. See the [Install and Configure
Docker](README.md#install-and-configure-docker) section in the README.

- A [Docker registry](https://docs.docker.com/registry/) that is accessible by
each machine that you plan to join to
the swarm. There are many offerings for Docker registries, including public
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

- `docker swarm init`

In general, the instructions and commands provided in this guide require you to
perform them on the manager node.

### Join other Machines to the Swarm Cluster

After you run init command above, you should see an output that looks like the
following:

```
docker swarm join \
    --token <token> \
    <manager ip address>:2377
```

Copy that command and run it on each machine that you want to be a part of the
swarm cluster.

## Build and Push the OpenMPF Docker Images

If you have not already done so, build the OpenMPF Docker images on the machine
that you used to clone the openmpf-docker repository by following the steps in
the [Build the OpenMPF Docker Images](README.md#build-the-openmpf-docker-images)
section in the README.

### Log into the Docker Registry

- `docker login -u <username> -p <password> <registry_host>:<registry_port>`

Note that the `<registry_host>:<registry_port>` part is optional. If omitted,
you will try to log into the [Docker Hub](https://hub.docker.com/). Use the
appropriate hostname and port number for your Docker registry.

### Tag and Push Images

Next, tag the images you built using this format:

`docker tag <image_name> <registry_host>:<registry_port>/<repository>/<image_name>:latest`

We assume that you'll be using a `<repository>` called "openmpf". Tag the
following images using the appropriate hostname and port number for your Docker
registry:

- `docker tag openmpf_active_mq <registry_host>:<registry_port>/openmpf/openmpf_active_mq:latest`

- `docker tag openmpf_docker_workflow_manager <registry_host>:<registry_port>/openmpf/openmpf_docker_workflow_manager:latest`

- `docker tag openmpf_docker_node_manager <registry_host>:<registry_port>/openmpf/openmpf_docker_node_manager:latest`

**IMPORTANT:** Change the image names in `swarm-compose.yml` to match your tags.

Next, push the images to the Docker registry:

- `docker-compose -f swarm-compose.yml push`

## Deploy to the Swarm Cluster

### Setup a Volume Driver

In order for Docker Swarm to keep a synchronized volume between the nodes in the
swarm, it needs a 3rd party volume driver. One of the simplest ways to do this
is to utilize a Network File System (NFS). If your network configuration does
not support NFS, or if you would like to make use of a cloud provider's storage
solution, then there are many other volume drivers that you can explore (i.e.
[REX-Ray](https://rexray.readthedocs.io/en/latest/)). This guide will be showing
how to do a deployment with NFS.

```
docker volume create --driver local --opt type=nfs \
    --opt o=addr=<address-of-file-share-server>,rw \
    --opt device=:<path-to-share-on-server> mpf_mpf-data
```

### Prevent Conflicts with the Host Network

#### Docker Ingress Network

When you run `docker swarm init`, Docker will automatically create an ingress
routing mesh network across all of the nodes. Sometimes the subnet that Docker
chooses conflicts with the subnet of the host machines running Docker. This
results in a condition where clients outside of the host subnet cannot access
Docker services running in that ingress network.

To prevent this, first inspect the ingress network that Docker created:

- `docker network inspect ingress`

Look for the following section in the output:

```
"IPAM": {
    "Driver": "default",
    "Options": null,
    "Config": [
        {
            "Subnet": "10.255.0.0/16",
            "Gateway": "10.255.0.1"
        }
    ]
},
```

Ensure that that subnet does not conflict with any of the subnets for the
network interfaces on the host machines. If so, recreate the ingress network as
follows:

- `docker network rm ingress`

Agree to the prompt.

- `docker network create -d overlay --subnet=<ingress-subnet-cidr> --ingress ingress`

Replace `<ingress-subnet-cidr>` with an appropriate non-conflicting IP address
range. For example, `8.8.8.0/24`.

#### Docker Overlay Network

Unless a subnet is specified for the application stack's network in
`swarm-compose.yml`, Docker will automatically create an overlay network for
secure node-to-node communication when you run `docker stack deploy`. Similar to
the ingress network issue described above, sometimes the subnet that Docker
chooses conflicts with the subnet of the host machines running Docker.

To prevent this, manually specify a subnet IP address range for the overlay
network in `swarm-compose.yml` as follows:

```
networks:
  mpf_default:
    driver: overlay
    ipam:
      config:
        - subnet: <overlay-subnet-cidr>
```

Replace `<overlay-subnet-cidr>` with an appropriate non-conflicting IP address
range. For example, `9.9.9.0/24`. Make sure this does not conflict with
`<ingress-subnet-cidr>`.

### Deploy the Stack to the Swarm

`docker stack deploy -c swarm-compose.yml mpf --with-registry-auth`

That stack will likely take a long time to come up the first time you deploy it
because if a container gets scheduled on a node where the image is not present
then it needs to download the image from the Docker registry, which takes some
time. This will be much faster later once the images are downloaded on the
nodes. If the images are updated, only the changes are downloaded from the
Docker registry.

#### Monitor the Swarm Services

List all of the services running across all of the nodes in the cluster:

- `docker service ls`

It may take a minute for all of the services to come up. It may be helpful to
run this command as:

- `watch -n 1 docker service ls`

That will run the command every second. Watch the `REPLICAS` column. Once all
of the replicas are up, then the stack is ready for use. If one of the replicas
does not come up, then there is a problem. Press ctrl+c when done.

List the task being executed by each service in the stack:

- `docker stack ps mpf`

Show the containers running on the current node:

- `docker ps`

#### Log into the Workflow Manager and Add Nodes

You can reach the workflow manager using IP address or hostname of any of the
nodes in the swarm. The request will be forwarded to the node that is hosting
the workflow manager container.

`http://<ip-address-or-hostname-of-any-node>:8080/workflow-manager`

Once you have logged in, go to the Nodes page and add all of the available
nodes. You should see that they each end in a unique ID. That number corresponds
to the ID of the Docker container. The number of node manager containers that
come up is determined by the `replicas:` field for each service listed in the
`swarm-compose.yml` file. Feel free to change it if you please.

#### Tearing Down the Stack

When you are ready to tear down the stack and remove the containers, run:

- `docker stack rm mpf`

To redeploy the stack, run the command that begins with `docker stack deploy`
again.