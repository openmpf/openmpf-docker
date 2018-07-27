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

### With Docker

OpenMPF can be built and deployed using Docker.
`Please note, it is recommend that you allocate extra system resources to Docker
 before executing the build steps. This is especially important for memory
 because the build requires a large amount of memory and will likely fail
 if it does not have enough. We recommend that you allocating the Docker daemon
 4 CPU cores, 10240 MB (10 GB) of memory (you may be able to get away with less
   but this is what we have been successful with), and 4096 MB (4 GB) of disk
   swap space.`

To do this, start by cloning the
[Openmpf-docker repository](https://github.com/openmpf/openmpf-docker).
- git clone https://github.com/openmpf/openmpf-docker.git
Once cloned (and assuming you have docker installed), you can run the following
command to build the OpenMPF project inside a docker container tagged as
`mpf_build:latest`
This container will take a while to build.
- `docker build mpf_build/ -t mpf_build:latest`.
Once it is complete, you can run
- `docker-compose build`
- `docker-compose up`
to run the project.

## Project Website

For more information about OpenMPF, including documentation, guides, and other material, visit our  [website](https://openmpf.github.io/).

## Project Workboard

For a latest snapshot of what tasks are being worked on, what's available to pick up, and where the project stands as a whole, check out our [workboard](https://github.com/orgs/openmpf/projects/3).
