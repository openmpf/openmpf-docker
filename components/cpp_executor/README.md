Overview
==================
The purpose of this image is to enable a developer to write a C++ component for OpenMPF that can be encapsulated
within a Docker container. This isolates the execution environment from the rest of OpenMPF,
thereby providing greater freedom and portability. The `openmpf_cpp_component_build` and `openmpf_cpp_executor` 
base images are designed to work together in a multi-stage Docker build.

This image will:

- Register your component with the Workflow Manager.
- Execute your code using the OpenMPF component executor binary.
- Tail log files so that they appear in the terminal window where you ran `docker run ..`
  to start your component container.
  
  
Build the base images
======================================================
```bash
cd /path/to/openmpf-docker/components
DOCKER_BUILDKIT=1 docker build . -f cpp_component_build/Dockerfile -t openmpf_cpp_component_build
DOCKER_BUILDKIT=1 docker build . -f cpp_executor/Dockerfile -t openmpf_cpp_executor
```


How to use the base images
===========================
The following steps assume you are using the default project structure for OpenMPF C++ components. Documentation
for C++ components can be found [here](https://openmpf.github.io/docs/site/CPP-Batch-Component-API). 

The [OcvFaceDetection component](https://github.com/openmpf/openmpf-components/tree/master/cpp/OcvFaceDetection) 
is a good example of a Dockerized C++ component that has no external dependencies.
The [TesseractOCRTextDetection component](https://github.com/openmpf/openmpf-components/tree/master/cpp/TesseractOCRTextDetection) 
is good example of Dockerized component that does have external dependencies.


### Create a Dockerfile in your C++ component project
You should put your Dockerfile in the component project's top level directory. For example:

```
MyFaceDetection
├── Dockerfile
├── CMakeLists.txt
├── MyFaceDetection.cpp
├── MyFaceDetection.h
└── plugin-files
    ├── config
    │   └── Log4cxxConfig.xml
    └── descriptor
        └── descriptor.json
```

The minimal Dockerfile is:
```dockerfile
# In first stage of the build we extend the openmpf_cpp_component_build base image.
FROM openmpf_cpp_component_build:latest as build_component

# If your component has external dependencies, you would add the commands necessary to download or
# build the dependencies here. Adding the dependencies prior the copying in your source code 
# allows you to take advantage of the Docker build cache to avoid re-installing the dependencies 
# every time your source code changes.
# e.g. RUN yum install -y mydependency

# Copy in your source code
COPY . .

# Build your component. The [build-component.sh](../cpp_component_build/scripts/build-component.sh) 
# script is provided by the openmpf_cpp_component_build base image.
RUN build-component.sh

# You optionally may want to run unit test here, or wherever is appropriate for your Dockerfile. 
# The [OcvFaceDetection component's Dockerfile](https://github.com/openmpf/openmpf-components/blob/master/cpp/OcvFaceDetection/Dockerfile) 
# shows one way of setting up unit tests, but you can do it in whatever way you see fit. 

# In the second stage of the build we extend the openmpf_cpp_executor base image. 
FROM openmpf_cpp_executor:latest

# If your component has runtime dependencies other than the shared libraries required at compile 
# time you should install them here. Adding the dependencies prior to copying your component's 
# build artifacts allows you to take advantage of the Docker build cache to avoid re-installing
# the dependencies every time your source code changes.


# Set the COMPONENT_LOG_NAME environment variable so that your component's log file can be 
# printed to standard out when running the image. 
# The log name is defined in plugin-files/config/Log4cxxConfig.xml.
ENV COMPONENT_LOG_NAME my-face-detection.log

# Copy only the files the component will need at runtime from the build stage. 
# This line also copies over the libraries that your component links to. 
# Note that running build-component.sh in the first stage collected those libraries for you.
COPY --from=build_component $BUILD_DIR/plugin/MyFaceDetection $INSTALL_DIR

# Copy over the library containing your component's compiled code.
COPY --from=build_component $BUILD_DIR/libmpfMyFaceDetection.so $INSTALL_DIR/lib
```

Your Dockerfile may use more than the two stages shown above, but the final stage in the Dockerfile must be the
`FROM openmpf_cpp_executor:latest` stage.


### Build your component image
Run the following command, replacing `<component_name>` with the name of your component and `<component_path>` with the
path on the host file system to the component project's top level directory:
```bash
docker build -t <component_name> <component_path>
```
For example: `docker build -t MyFaceDetection /path/to/MyFaceDetection`.


### Run your component
1. Start OpenMPF
2. Run the following command replacing `<component_name>` with the value provided in the build step. 
   If your OpenMPF deployment uses non-default credentials the `WFM_USER` and `WFM_PASSWORD` values will need to be 
   modified.
```bash
docker run \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    <component_name>
```
