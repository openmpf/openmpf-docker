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
system. Next, stop Docker:

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

### Build the OpenMPF Docker Images

Note that this process can take 1.5 - 2 hours if you're starting from scratch.

Clone the [openmpf-docker repository](https://github.com/openmpf/openmpf-docker):

- `git clone https://github.com/openmpf/openmpf-docker.git`

Clone the [openmpf-projects
repository](https://github.com/openmpf/openmpf-projects) into the `mpf_build`
directory:
- `cd openmpf-docker/mpf_build/`
- `git clone https://github.com/openmpf/openmpf-projects.git --recursive`
- (Optional) checkout a branch or commit
  - `cd openmpf-projects`
  - `git checkout <branch or commit>`
  - `git submodule update --init`

Download the most recent Oracle Java SE JDK 8 64-bit Linux RPM from
[here](http://www.oracle.com/technetwork/java/javase/downloads/index.html). If
it's not listed there, check
[here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html).
Place the file in the `mpf_build` directory. The file should be named
`jdk-8u144-linux-x64.rpm`, or something similar where "8u144" is a different
version number. Do not download Java SE 9 or 10.

Once cloned, run  following command from within the `openmpf-docker` directory
to create the OpenMPF build image:

- `docker build mpf_build/ -t mpf_build:latest`

This image has not yet built OpenMPF, rather, it is an environment in which
OpenMPF will be built in the next step.

Next, decide where you would like to store the Maven dependencies on your host
system. On Linux systems, they are usually stored in `~/.m2`. Create a new `.m2`
directory if necessary.

The first time OpenMPF is built it will download 300+ MB of Maven dependencies.
It is most efficient to store them all on the host system so that they do not
need to be downloaded again if and when you rebuild OpenMPF.

Perform the build using the following command:

```
docker run \
  --mount type=bind,source=<path-to-.m2-dir>,target=/root/.m2 \
  --mount type=bind,source="$(pwd)"/mpf_runtime/build_artifacts,target=/home/mpf/build_artifacts \
  mpf_build
```

If that command does output `BUILD SUCCESS` then you may try to run it again.
Sometimes Maven will time out while trying to download dependencies within a
Docker container.

If you built the runtime images before, then run the following commands to
remove the old containers and volumes:

- `docker-compose rm`
- `docker volume rm openmpf-docker_mpf_data`
- `docker volume rm openmpf-docker_mysql_data`

Create the new runtime images:

- `docker-compose build`

### Run OpenMPF using Docker Compose

Once the runtime images are built, you can run OpenMPF using:

- `docker-compose up`

The output from each of the services will be piped to the terminal. Wait until
you see a line similar to the following generated by the workflow manager
container:

> INFO: Server startup in 26967 ms

#### Log into the Workflow Manager and Add Nodes

You can reach the workflow manager at the following URL:

`http://<ip-address-or-hostname-of-docker-host>:8080/workflow-manager`

Once you have logged in, go to the Nodes page and add all of the available
nodes.

#### Monitor the Containers

Show the containers running on the current node:

- `docker ps`

#### Tearing Down the Containers

You can stop the containers by pressing ctrl+c (sometimes, twice) in the
terminal you ran `docker-compose up` and then running:

- `docker-compose stop`

If you prefer, you can also stop and remove all of the containers and networks
by running:

- `docker-compose down`

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

Now that you have both of those installed, you can specify the `runtime: nvidia`
flag for the node manager container. This can be done by uncommenting the flag
in the [docker-compose.yml](docker-compose.yml) file.

After you launch OpenMPF with the NVIDIA runtime specified, you need to login
and go to the Properties page under Configuration in the top menu bar, then set
the `detection.cuda.device.id property` to 0, or the CUDA index of your GPU
device.

### (Optional) Docker Swarm Deployment

OpenMPF can be deployed in a distributed environment if you would like to take
advantage of running the project, and scheduling jobs, across multiple physical
or virtual machines. The simplest way to do this is to set up a Docker Swarm
deployment. If you would like a walkthrough on how to do that, please see the
[Swarm deployment guide](SWARM.md).

## Project Website

For more information about OpenMPF, including documentation, guides, and other material, visit our  [website](https://openmpf.github.io/).

## Project Workboard

For a latest snapshot of what tasks are being worked on, what's available to pick up, and where the project stands as a whole, check out our [workboard](https://github.com/orgs/openmpf/projects/3).
