# OpenMPF Docker

Welcome to the Open Media Processing Framework (OpenMPF) Docker Project!

## What is the OpenMPF?

OpenMPF provides a platform to perform content detection and extraction on bulk multimedia, enabling users to analyze, search, and share information through the extraction of objects, keywords, thumbnails, and other contextual data.

OpenMPF enables users to build configurable media processing pipelines, enabling the rapid development and deployment of analytic algorithms and large-scale media processing applications.

### Search and Share

Simplify large-scale media processing and enable the extraction of meaningful content

### Open API

Apply cutting-edge algorithms such as face detection and object classification

### Flexible Architecture

Integrate into your existing environment or use OpenMPF as a standalone application

## Overview

This repository contains code for the OpenMPF Dockerfiles and related files.

## Where Am I?

- [Parent OpenMPF Project](https://github.com/openmpf/openmpf-projects)
- [OpenMPF Core](https://github.com/openmpf/openmpf)
- Components
    * [OpenMPF Standard Components](https://github.com/openmpf/openmpf-components)
    * [OpenMPF Contributed Components](https://github.com/openmpf/openmpf-contrib-components)
- Component APIs:
    * [OpenMPF C++ Component SDK](https://github.com/openmpf/openmpf-cpp-component-sdk)
    * [OpenMPF Java Component SDK](https://github.com/openmpf/openmpf-java-component-sdk)
    * [OpenMPF Python Component SDK](https://github.com/openmpf/openmpf-python-component-sdk)
- [OpenMPF Build Tools](https://github.com/openmpf/openmpf-build-tools)
- [OpenMPF Web Site Source](https://github.com/openmpf/openmpf.github.io)
- [OpenMPF Docker](https://github.com/openmpf/openmpf-docker) ( **You are here** )

## Getting Started

### Install and Configure Docker

Download and install Docker for your OS
[here](https://www.docker.com/community-edition#/download).

We recommend that you allocate extra system resources to Docker before executing
the build steps. This is especially important because the build requires a large
amount of memory and will likely fail if it does not have enough. We recommend
that you allocate the Docker daemon 4 CPU cores, 10240 MB (10 GB) of memory
(you may be able to get away with less but this is what we have been successful
with), and 4096 MB (4 GB) of disk swap space.

#### Check the Linux Host Storage Driver

The [official Docker
documentation](https://docs.docker.com/storage/storagedriver/select-storage-driver/)
recommends using the overlay2 storage driver for Linux hosts over the
devicemapper storage driver. In general, the devicemapper storage driver does
not perform well in production environments. When installing Docker on Linux,
check which storage driver Docker chose by default:

- `docker info | grep Storage`

If this prints out `Storage Driver: overlay2` then nothing more needs to be
done. Instead, if it prints out `Storage Driver: devicemapper`, then we
recommend changing it. The following steps assume that you've installed Docker
Community Edition (CE) on a CentOS 7 host. If you installed Docker Enterprise
Edition (EE), and/or are using a different flavor of Linux, then refer to the
official steps
[here](https://docs.docker.com/storage/storagedriver/overlayfs-driver/).

First check that you're running at least version 3.10.0-514 of higher of the
Linux kernel:

- `uname -r`

If you're running an older version of the kernel then consider upgrading your
system. Next, check the root partition:

- `df -hT`

This will print some output. For example:

```
Filesystem                                    Type      Size  Used Avail Use% Mounted on
/dev/mapper/centos-root                       xfs        50G  8.5G   42G  17% /
devtmpfs                                      devtmpfs  3.9G     0  3.9G   0% /dev
tmpfs                                         tmpfs     3.9G     0  3.9G   0% /dev/shm
tmpfs                                         tmpfs     3.9G  417M  3.5G  11% /run
tmpfs                                         tmpfs     3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/sda1                                     xfs       497M  305M  192M  62% /boot
/dev/mapper/centos-home                       xfs        87G  5.1G   82G   6% /home
```

Here we see that the root partition is mounted to `/` and has type `xfs`. In
order to use overlay2 on an xfs filesystem, the d_type option must be enabled.
To check that run:

- `xfs_info <mount_point>`

For example:

```
[root@somehost ~]# xfs_info /
meta-data=/dev/mapper/centos-root isize=256    agcount=4, agsize=3276800 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=0        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=13107200, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=0
log      =internal               bsize=4096   blocks=6400, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

Here we see that `ftype=0`. That means d_type is not enabled, so if you wish to
use overlay2 you will need to recreate the root partition with that option
enabled. See
[here](http://www.pimwiddershoven.nl/entry/docker-on-centos-7-machine-with-xfs-filesystem-can-cause-trouble-when-d-type-is-not-supported).

Once you've determined that your Linux setup can support overlay2, stop Docker:

- `sudo systemctl stop docker`

Edit `/etc/docker/daemon.json`. If that file does not already exist, then create
it. Assuming it's empty, add the following content:

```
{
  "storage-driver": "overlay2"
}
```

Next, start Docker:

- `sudo systemctl start docker`

Check that the correct storage driver is now in use:

- `docker info | grep Storage`

This should now print out `Storage Driver: overlay2`. Repeat these steps on each
of your Docker nodes.

#### Install Docker Compose

If you installed Docker for Mac or Docker for Windows, then `docker-compose`
should already be included. If you are installing on Linux, you will need to
follow the instructions found [here](https://docs.docker.com/compose/install/).

Please make sure you have at least `version 1.22.0` installed before continuing.
To check this, run:

-  `docker-compose --version`

#### Other Programs

If you installed Docker for Windows, then please install a program that allows
you to run bash scripts in a Unix-like terminal environment. We recommend Git
Bash, which is part of [Git for Windows](https://gitforwindows.org/), or
[Cygwin](https://cygwin.com/install.html).

### Build the OpenMPF Docker Images

Note that this process can take an hour if you're starting from scratch.

#### Setup
Clone the [openmpf-projects
repository](https://github.com/openmpf/openmpf-projects) somewhere on your host
system:
- `git clone https://github.com/openmpf/openmpf-projects.git --recursive`
- (Optional) checkout a branch or commit
  - `cd openmpf-projects`
  - `git checkout <branch or commit>`
  - `git submodule update --init`

If you plan to develop and integrate your own component into OpenMPF, then
please refer to the [Contribution Guide](CONTRIBUTING.md).

#### Create the OpenMPF Build Image

<span id="docker-build-command"></span>
Run the following command from within the `openmpf-docker` directory to create
the OpenMPF build image:

- `DOCKER_BUILDKIT=1 docker build -f openmpf_build/Dockerfile .. -t openmpf_build`


#### Build the OpenMPF Component Executor Docker Images
<span id="component-executors-build-commands"></span>

Run the commands in this section from within the `openmpf-docker/components` directory.

Run the following command to create the OpenMPF Python component build image:
- `DOCKER_BUILDKIT=1 docker build . -f python_component_build/Dockerfile -t openmpf_python_component_build`

Run the following command to create the OpenMPF Python component executor image:
- `DOCKER_BUILDKIT=1 docker build . -f python_executor/Dockerfile -t openmpf_python_executor`

Run the following command to create the OpenMPF C++ component build image:
- `DOCKER_BUILDKIT=1 docker build . -f cpp_component_build/Dockerfile -t openmpf_cpp_component_build`

Run the following command to create the OpenMPF C++ component executor image:
- `DOCKER_BUILDKIT=1 docker build . -f cpp_executor/Dockerfile -t openmpf_cpp_executor`

Run the following command to create the OpenMPF Java component build image:
- `DOCKER_BUILDKIT=1 docker build . -f java_component_build/Dockerfile -t openmpf_java_component_build`

Run the following command to create the OpenMPF Java component executor image:
- `DOCKER_BUILDKIT=1 docker build . -f java_executor/Dockerfile -t openmpf_java_executor`

#### Generate docker-compose.yml

From within the `openmpf-docker` directory, copy `env.tpl` to `.env` and set
environment variables in `.env`. Make sure that `OPENMPF_PROJECTS_PATH` is
set correctly.

The default user password settings are public knowledge, which could be a
security risk. To configure your own user settings, see
[below](#optional-configure-users).

Leave the `KEYSTORE_` variables in `.env`  blank when configuring the Workflow
Manager to use HTTP. To enable HTTPS, see [below](#optional-configure-https).

Run the following command to generate a stand-alone `docker-compose.yml` file:

```
docker-compose \
   -f docker-compose.core.yml \
   -f docker-compose.components.yml \
   config > docker-compose.yml
```

Optionally, you can make further customizations to the `docker-compose.yml` file
by generating it with your own `docker-compose.custom.yml` file as follows:

```
docker-compose \
   -f docker-compose.core.yml \
   -f docker-compose.components.yml \
   -f docker-compose.custom.yml \
   config > docker-compose.yml
```

#### Build the OpenMPF Runtime Docker Images

If you built the runtime images before, then run the following command to
remove the old containers and volumes:

- `docker-compose down -v`

Run the following command to create the new runtime images:

- `docker-compose build`

### Run OpenMPF using Docker Compose

Once the runtime images are built, you can run OpenMPF using:

- `docker-compose up`

Note that if you want to run more than one instance of a service type,
you will need to use the `--scale` option. For example:

- `docker-compose up --scale east-text-detection=2 other_service=3`

The output from each of the services will be piped to the terminal. Wait until
you see a line similar to the following generated by the Workflow Manager
container:

> INFO: Server startup in 26967 ms

#### Log into the Workflow Manager

You can reach the Workflow Manager at the following URL:

`http://<ip-address-or-hostname-of-docker-host>:8080/workflow-manager`

After logging in, you can see which components are registered by clicking on 
the "Configuration" dropdown from the top menu bar and then clicking on 
"Component Registration".

#### Monitor the Containers

Show the containers running on the current node:

- `docker ps`

#### Tearing Down the Containers

When you are ready to stop the OpenMPF deployment, you have the following
options:

**Persist State**

If you would like to persist the state of OpenMPF so that the next time you run
`docker-compose up` the same job information, log files, custom property
settings, custom pipelines, etc., are used, then press ctrl+c in the same
terminal you ran `docker-compose up`. That will stop the running containers.

Alternatively, you can run the following command in a different terminal:

- `docker-compose stop`

Both approaches preserve the Docker volumes.

**Clean Slate**

If you would like to start from a clean slate the next time you run
`docker-compose up`, as though you had never deployed OpenMPF before, then run
the following command from within the `openmpf-docker` directory:

- `docker-compose down -v`

This will remove all of the OpenMPF Docker containers, volumes, and networks.
It does not remove the Docker images.

**Remove All Images**

To remove all of the OpenMPF Docker containers, volumes, networks, and images,
then run the following command from within the `openmpf-docker` directory:

- `docker-compose down -v --rmi all`

### (Optional) Docker Swarm Deployment

OpenMPF can be deployed in a distributed environment if you would like to take
advantage of running the project, and scheduling jobs, across multiple physical
or virtual machines. The simplest way to do this is to set up a Docker Swarm
deployment. If you would like a walkthrough on how to do that, please see the
[Swarm Deployment Guide](SWARM.md).

### (Optional) Configure Users

Copy
`openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/properties/user.properties` ([link](https://github.com/openmpf/openmpf/blob/master/trunk/workflow-manager/src/main/resources/properties/user.properties))
somewhere on the swarm manager host and make modifications to that file. Then
set the `USER_PROPERTIES_PATH` variable in the `.env` file to the location of
that file.

Run the following command to generate the stand-alone `docker-compose.yml` file:

```
docker-compose \
   -f docker-compose.core.yml \
   -f docker-compose.users.yml \
   -f docker-compose.components.yml \
   config > docker-compose.yml
```

If configuring your deployment with HTTPS, you will also need to add
`-f docker-compose.https.yml` to the above command.

### (Optional) Configure HTTPS

The Workflow Manager web application can be configured to use HTTPS. To enable
HTTPS you must set the `KEYSTORE_` variables in the `.env` file.

When using a Docker Compose deployment, `KEYSTORE_PATH` is the path to the
keystore on the host's file system. When using a Docker Swarm deployment,
`KEYSTORE_PATH` is the path to the keystore on the swarm manager host's file
system. The keystore only needs to be present on the swarm manager. The Java
JKS and PKCS#12 keystore formats are supported.

Run the following command to generate the stand-alone `docker-compose.yml` file:

```
docker-compose \
   -f docker-compose.core.yml \
   -f docker-compose.https.yml \
   -f docker-compose.components.yml \
   config > docker-compose.yml
```

If configuring your deployment with custom user password settings, you will also
need to add `-f docker-compose.users.yml` to the above command.


### (Optional) Import Root Certificates for Additional Certificate Authorities

The Workflow Manager can be configured to trust additional certificate 
authorities. The Workflow Manager uses these certificates when it 
acts as an HTTPS client. For example, remote media download and job status 
callbacks.

To import additional root certificates add an entry for `MPF_CA_CERTS` to
the `workflow-manager` service's environment variables in 
`docker-compose.core.yml`. `MPF_CA_CERTS` must contain a colon-delimited list 
of absolute file paths. Each entry in `MPF_CA_CERTS` will be added to 
Workflow Manager's trust store. This feature is intended to be used with
a volume mounted to the Workflow Manager container containing the certificates, 
but the paths can refer to any path the container has access to (e.g. Docker 
configs, secrets, and bind mounts).


### (Optional) Use Kibana for Log Viewing and Aggregation
To use [Kibana](https://www.elastic.co/kibana) to view OpenMPF logs, 
you will need to add `-f docker-compose.elk.yml` to your 
`docker-compose config` command. After running `docker-compose up`, 
Kibana can be accessed at 
`http://<ip-address-or-hostname-of-docker-host>:5601`. Kibana comes with
many apps, but the only ones likely to be useful are 
Logs (`http://<ip-address-or-hostname-of-docker-host>:5601/app/infra#/logs`)
and 
Discover (`http://<ip-address-or-hostname-of-docker-host>:5601/app/kibana#/discover`).

If you have Docker configured to use a non-standard root directory,
then you will need to change the volume configuration for the 
filebeat service in `docker-compose.elk.yml` from 
`/var/lib/docker/containers:/var/lib/docker/containers:ro` to 
`/path/to/docker-dir/containers:/var/lib/docker/containers:ro`.

If you have Docker configured to use a non-standard location for 
the Docker socket, then you will need to change the volume configuration 
for the filebeat service in `docker-compose.elk.yml` from 
`/var/run/docker.sock:/var/run/docker.sock:ro` to 
`/path/to/docker.sock:/var/run/docker.sock:ro`.


### (Optional) Add GPU support with NVIDIA CUDA

To run OpenMPF components that use the NVIDIA GPUs, you must
ensure that the host OS of the GPU machine has version 9.1 or higher of the
NVIDIA GPU drivers installed. To install the drivers, please see the full
instructions
[here](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html).

Once you have the drivers installed on the host OS, you need to install the
NVIDIA Docker runtime. Follow
[this](https://github.com/NVIDIA/nvidia-docker/blob/master/README.md)
installation guide.

To get the nodes in your swarm cluster to use the NVIDIA Docker runtime, you
will need to update the `/etc/docker/daemon.json` file on each node. If that
file does not already exist, then create it. Add the following content:

```
{   
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

This setting will affect every container running on the node, which, in general,
should not cause any problems for containers that don't require a special
runtime.

After you launch OpenMPF with the NVIDIA runtime specified, you need to login
and go to the Properties page under Configuration in the top menu bar, then set
the `detection.cuda.device.id property` to 0, or the CUDA index of your GPU
device.

### (Optional) Running Tests
Build the `openmpf_cpp_component_build`, `openmpf_cpp_executor`, and `openmpf_python_executor` 
images as directed [above](#component-executors-build-commands). Then, from within the `openmpf-docker` directory run:
```shell script
docker build -f openmpf_build/Dockerfile path/to/openmpf-projects -t openmpf_build --build-arg RUN_TESTS=true
export COMPOSE_FILE='docker-compose.integration.test.yml:docker-compose.components.yml'
docker-compose build --build-arg RUN_TESTS=true
docker-compose up --exit-code-from workflow-manager
docker-compose down -v
unset COMPOSE_FILE
```

### (Optional) Restrict Media Types That a Component Can Process
Component services can be configured to only process certain types of media.
This is done by setting a component service's `RESTRICT_MEDIA_TYPES` 
environment variable in `docker-compose.components.yml` to a comma-separated 
list containing one or more of `VIDEO`, `IMAGE`, `AUDIO`, `UNKNOWN`. 
If you want different instances of a particular component to process different 
media types, you can add multiple entries for that component to 
`docker-compose.components.yml`.
For example:
```yaml
services:
  ocv-face-detection-image-only:
    <<: *detection-component-base
    image: ${REGISTRY}openmpf_ocv_face_detection:${TAG}
    build: ${OPENMPF_PROJECTS_PATH}/openmpf-components/cpp/OcvFaceDetection
    environment:
      <<: *common-env-vars
      RESTRICT_MEDIA_TYPES: IMAGE

  ocv-face-detection-image-video-only:
    <<: *detection-component-base
    image: ${REGISTRY}openmpf_ocv_face_detection:${TAG}
    build: ${OPENMPF_PROJECTS_PATH}/openmpf-components/cpp/OcvFaceDetection
    environment:
      <<: *common-env-vars
      RESTRICT_MEDIA_TYPES: VIDEO, IMAGE

  # This instance will process all media types
  ocv-face-detection:
    <<: *detection-component-base
    image: ${REGISTRY}openmpf_ocv_face_detection:${TAG}
    build: ${OPENMPF_PROJECTS_PATH}/openmpf-components/cpp/OcvFaceDetection
```


## Project Website

For more information about OpenMPF, including documentation, guides, and other material, visit our [website](https://openmpf.github.io/).

## Project Workboard

For a latest snapshot of what tasks are being worked on, what's available to pick up, and where the project stands as a whole, check out our [workboard](https://github.com/orgs/openmpf/projects/3).
