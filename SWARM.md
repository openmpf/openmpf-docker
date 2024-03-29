# Deploy OpenMPF with Docker Swarm

## Do I need Swarm Deployment?

If you would like to run OpenMPF across multiple physical or virtual machines then we recommend following this guide to
setup a
[Docker Swarm](https://docs.docker.com/engine/swarm/) deployment. Instead, if you would like to run OpenMPF on one
machine, for example, to quickly test out the software, then we recommend running `docker compose up` as explained in
the
[README](README.md).

## Prerequisites

1. A cluster of machines running the Docker daemon. The client and daemon
   (server) API must both be at least version 1.24. Use the `docker version` command to check your client and daemon API
   versions. See the [Install and Configure Docker](README.md#install-and-configure-docker) section in the README.<br/>

2. A [Docker registry](https://docs.docker.com/registry/) that is accessible by each machine that you plan to join to
   the swarm. There are many offerings for Docker registries, including public cloud-hosted registries, such
   as [Docker Hub](https://hub.docker.com/), private cloud-hosted registries, or
   [self-hosted registries](https://github.com/docker/distribution). Feel free to pick the solution that works best for
   you, but please note that if you choose to host any images on a public registry, you accept responsibility for the
   usage of those images.<br/>

3. A stand-alone `docker-compose.yml` file. If you don't have one then you may wish to use the one provided in the "
   Quick Start" section of the documentation for the OpenMPF Workflow Manager image
   on [Docker Hub](https://hub.docker.com/r/openmpf/openmpf_workflow_manager), or follow the instructions in
   the [Generate docker-compose.yml](README.md#generate-docker-composeyml) section in the README.<br/>

4. A local copy of the [openmpf-docker repository](https://github.com/openmpf/openmpf-docker) somewhere on the swarm
   manager host so you can run scripts:<br/>

    - `git clone https://github.com/openmpf/openmpf-docker.git`
        - (Optional) checkout a branch or commit
        - `git checkout <branch or commit>`

## Set Up The Swarm Cluster

### Initialize the Swarm Cluster

Choose a machine that you wish to act as the manager node. You will be able to deploy and manage the stack from this
node. Run the following command on that node:

- `docker swarm init`

In general, the instructions and commands provided in this guide require you to perform them on the manager node.

### Join other Machines to the Swarm Cluster

After you run init command above, you should see an output that looks like the following:

```
docker swarm join \
    --token <token> \
    <manager ip address>:2377
```

Copy that command and run it on each machine that you want to be a part of the swarm cluster.

## Push the OpenMPF Docker Images

If you have not already done so, pull or build the OpenMPF Docker images on the machine that you used to clone the
openmpf-docker repository by following the steps in
the [Pull or Build the OpenMPF Docker Images](README.md#pull-or-build-the-openmpf-docker-images)
section in the README.

In order to push the images to your own Docker registry, they each need to be named with the appropriate prefix for your
registry. The format is:

`<registry_host>:<registry_port>/<registry_path>/<openmpf_component_name>`

For example:

`myregistry.com/openmpf/openmpf_ocv_face_detection`

In the above example we omit the port. It's optional.

You may need to [tag](https://docs.docker.com/engine/reference/commandline/tag/) your images to name them properly. If
you omit the `<registry_host>:<registry_port>/` part of the registry prefix then Docker will assume you want to push the
images to
[Docker Hub](https://hub.docker.com/) when you later execute the `push` command.

Ensure that the values for the `image` fields in your `docker-compose.yml` file match your image names.

Log into the Docker registry:

- `docker login -u <username> -p <password> <registry_host>:<registry_port>`

Note that the `<registry_host>:<registry_port>` part is optional. If omitted, you will try to log into Docker Hub.

Push the images by running the following command within the same directory as `docker-compose.yml`:

- `docker compose push`

## Deploy to the Swarm Cluster

### Setup a Shared Volume

In order for Docker Swarm to keep a synchronized volume between the nodes in the swarm, it needs a third party volume
driver. One of the simplest ways to do this is to utilize a Network File System (NFS)
. [This guide](https://www.howtoforge.com/nfs-server-and-client-on-centos-7) explains how to set up an NFS share on
CentOS machines.

If your network configuration does not support NFS, or if you would like to make use of a cloud provider's storage
solution, then there are many other volume drivers that you can explore (i.e.
[REX-Ray](https://rexray.readthedocs.io/en/latest/)). Assuming you have an NFS share already setup, run the following
command on each node to create a volume for sharing OpenMPF data:

```
docker volume create --driver local --opt type=nfs \
    --opt o=addr=<address-of-file-share-server>,rw \
    --opt device=:<path-to-share-on-server> openmpf_shared_data
```

Note that Docker takes care of mounting the NFS share on each node, so you do not need to mount the NFS share yourself (
i.e. you don't need to modify
`/etc/fstab` on each node). Also, note that removing the Docker volume does not delete the data generated in the NFS
share.

### Prevent Conflicts with the Host Network

#### Docker Ingress Network

When you run `docker swarm init`, Docker will automatically create an ingress routing mesh network across all of the
nodes. Sometimes the subnet that Docker chooses conflicts with the subnet of the host machines running Docker. This
results in a condition where clients outside of the host subnet cannot access Docker services running in that ingress
network.

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

Ensure that that subnet does not conflict with any of the subnets for the network interfaces on the host machines. If
so, recreate the ingress network as follows:

- `docker network rm ingress`

Agree to the prompt.

- `docker network create -d overlay --subnet=<ingress-subnet-cidr> --ingress ingress`

Replace `<ingress-subnet-cidr>` with an appropriate non-conflicting IP address range. For example, `8.8.8.0/24`.

#### Docker Overlay Network

Unless a subnet is specified for the application stack's network in
`docker-compose.core.yml`, Docker will automatically create an overlay network for secure node-to-node communication
when you run `docker stack deploy`. Similar to the ingress network issue described above, sometimes the subnet that
Docker chooses conflicts with the subnet of the host machines running Docker.

To prevent this, manually specify a subnet IP address range for the overlay network in `docker-compose.core.yml` as
follows:

```
networks:
  default:
    driver: overlay
    ipam:
      config:
        - subnet: <overlay-subnet-cidr>
```

Replace `<overlay-subnet-cidr>` with an appropriate non-conflicting IP address range. For example, `9.9.9.0/24`. Make
sure this does not conflict with
`<ingress-subnet-cidr>`.

### Modify docker-compose.yml

Note that by default both the Workflow Manager and PostgreSQL containers have a
`placement` constraint in `docker-compose.yml` so that they are always deployed to the swarm manager node:

```
    deploy:
      placement:
        constraints:
          - node.role == manager
```

The PostgreSQL container must always run on the same node so that the same
`openmpf_db_data` volume is used when the swarm is redeployed. The Workflow Manager container is run on the same node
for efficiency. If you wish to change the node, then modify the `placement` constraints.

By default, one instance of each detection component service is configured to run on each node in the swarm cluster:

```
    deploy:
      mode: global
```

For example, if you wish to deploy a specific number of instances, then use the following instead:

```
    deploy:
      mode: replicated
      replicas: 2
```

The [docker-compose file schema](https://docs.docker.com/compose/compose-file/#deploy) offers many ways to configure how
services are deployed. Among others, you may be also interested
in [resource limits and reservations](https://docs.docker.com/compose/compose-file/#resources).

If you need access to the actual hostname where Workflow Manager is deployed,
you can set an environment variable to `{{.Node.Hostname}}`. For example:
```yaml
  workflow-manager:
    environment:
      NODE_HOSTNAME: {{.Node.Hostname}}
```

### Deploy the Stack to the Swarm

`docker stack deploy openmpf -c docker-compose.yml --with-registry-auth`

The stack will likely take a long time to come up the first time you deploy it because if a container gets scheduled on
a node where the image is not present then it needs to download the image from the Docker registry, which takes some
time. This will be much faster later once the images are downloaded on the nodes. If the images are updated, only the
changes are downloaded from the Docker registry.

#### Monitor the Swarm Services

It may be helpful to run:

- `watch -n 1 docker stack ps -f desired-state=running openmpf --no-trunc`

The output will update every second. Watch the `CURRENT STATE` column. Once all of the service are `Running`, then the
stack is ready for use. Press ctrl+c when done.

Additionally, it may be helpful to run:

- `watch -n 1 docker service ls`

Again, the output will update every second. Watch the `REPLICAS` column. Once all of the replicas are up, then the stack
is ready for use. If one of the replicas does not come up, then there is a problem. Press ctrl+c when done.

To monitor the log of the Workflow Manager, run:

- `docker service logs --follow openmpf_workflow-manager`

Press ctrl+c when done.

#### Log into the Workflow Manager

You can reach the Workflow Manager using IP address or hostname of any of the nodes in the swarm. The request will be
forwarded to the node that is hosting the Workflow Manager container.

`http://<ip-address-or-hostname-of-any-node>:8080`

After logging in, you can see which components are registered by clicking on the "Configuration" dropdown from the top
menu bar and then clicking on
"Component Registration".

#### Tearing Down the Stack

When you are ready to stop the OpenMPF stack, you have the following options:

**Persist State**

If you would like to persist the state of OpenMPF so that the next time you run the command that begins
with `docker stack deploy` the same job information, log files, custom property settings, custom pipelines, etc., are
used, then run the following command from within the `openmpf-docker` directory:

- `./scripts/docker-swarm-cleanup.sh openmpf`

This preserves all of the Docker volumes.

The next time you deploy OpenMPF, all of the previous container logs will appear in the Logs web UI. To reduce clutter,
consider running the following command to archive and remove the old log files, where
`<output-dir>` is a directory on the swarm manager host:

- `./scripts/docker-swarm-logs.sh --rm -o <output-dir>`

**Clean Slate**

If you would like to start from a clean slate the next time you run the command that begins with `docker stack deploy`,
as though you had never deployed the stack before, then run the following commands from within the `openmpf-docker`
directory:

- `./scripts/docker-swarm-cleanup.sh openmpf --rm-all`
- `./scripts/docker-swarm-run-on-all-nodes.sh 'docker volume rm openmpf_db_data'`

As a convenience, this does not remove the shared volume so that you don't have to recreate it on all of the nodes the
next time you deploy the stack.

The `--rm-all` option will delete the contents the shared volume, which may include extracted artifacts, log files,
markup, remote media, etc. If you wish to preserve the contents of the shared volume, then omit that option. If you wish
to remove the contents of the shared volume at a later time, then run:

- `./scripts/docker-swarm-clean-shared-volume.sh`

**Remove All Volumes**

To remove all of the OpenMPF Docker containers, volumes, and networks, then run the following commands from within
the `openmpf-docker` directory:

- `./scripts/docker-swarm-cleanup.sh openmpf --rm-all`
- `./scripts/docker-swarm-run-on-all-nodes.sh 'docker volume rm openmpf_shared_data openmpf_db_data'`

This does not remove the Docker images.
