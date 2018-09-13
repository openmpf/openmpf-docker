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

Also install the docker-compose command

If you installed Docker for Mac or Docker for Windows, then docker-compose
should already be included. If you are installing on Linux, you will need to
follow the instructions found [here](https://docs.docker.com/compose/install/).

Please make sure you have at least `version 1.22.0` installed before continuing.
To check this, run `docker-compose --version`.

### Build the OpenMPF Docker Images

Clone the [openmpf-docker repository](https://github.com/openmpf/openmpf-docker):
- `git clone https://github.com/openmpf/openmpf-docker.git`

Download the most recent Oracle Java SE JDK 8 64-bit Linux RPM from [here](http://www.oracle.com/technetwork/java/javase/downloads/index.html). If
it's not listed there, check
[here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html).
Place the file in the mpf_build/ directory. The file should be named
`jdk-8u144-linux-x64.rpm`, or something similar where "8u144" is a different
version number. Do not download Java SE 9 or 10.

Once cloned, you can run the following command to build the OpenMPF project
inside a Docker container tagged as
`mpf_build:latest`:
- `docker build mpf_build/ -t mpf_build:latest`

Note that it can take 1.5 - 2 hours for this command to complete if you're
starting from scratch.

- `docker-compose build`

### Run OpenMPF using Docker Compose

Once the images are built, you can run OpenMPF using:
- `docker-compose up`

You can stop the containers pressing ctrl+c and then running
- `docker-compose stop`

You can also stop and remove all of the containers, and networks by running
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
