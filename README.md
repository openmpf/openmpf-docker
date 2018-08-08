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

Download and install Docker for your OS [here](https://www.docker.com/community-edition#/download).

We recommend that you allocate extra system resources to Docker before executing the build steps. This is especially important because the build requires a large amount of memory and will likely fail if it does not have enough. We recommend that you allocate the Docker daemon 4 CPU cores, 10240 MB (10 GB) of memory (you may be able to get away with less but this is what we have been successful with), and 4096 MB (4 GB) of disk swap space.

### Build and Run the OpenMPF Containers

Clone the [openmpf-docker repository](https://github.com/openmpf/openmpf-docker):
- `git clone https://github.com/openmpf/openmpf-docker.git`

Download the most recent Oracle JDK (Java SE 8 or newer) 64-bit Linux RPM from
[here](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
and place it in the mpf_build/ directory. The file should be named
jdk-8u144-linux-x64.rpm, or something similar where "8u144" is a different
version number.

Once cloned, you can run the following command to build the OpenMPF project inside a docker container tagged as
`mpf_build:latest`:
- `docker build mpf_build/ -t mpf_build:latest`

Note that it can take 1.5 - 2 hours for this command to complete if you're starting from scratch.

Once it is complete, you can run the project using:
- `docker-compose build`
- `docker-compose up`

## Project Website

For more information about OpenMPF, including documentation, guides, and other material, visit our  [website](https://openmpf.github.io/).

## Project Workboard

For a latest snapshot of what tasks are being worked on, what's available to pick up, and where the project stands as a whole, check out our [workboard](https://github.com/orgs/openmpf/projects/3).
