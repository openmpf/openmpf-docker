Overview
==================
The purpose of this image is to enable a developer to write a Python component for OpenMPF that can be encapsulated
within a Docker container. This isolates the execution environment from the rest of OpenMPF,
thereby providing greater freedom and portability. The `openmpf_python_component_build` and `openmpf_python_executor` 
base images are designed to work together in a multi-stage Docker build.

This image will:

- Register your component with the Workflow Manager.
- Execute your code using the OpenMPF component executor binary.
- Tail log files so that they appear in the terminal window where you ran `docker run ..`
  to start your component container.
  
  
How to build the `openmpf_python_component_build` and `openmpf_python_executor` base images
======================================================
```bash
cd /path/to/openmpf-docker/components
DOCKER_BUILDKIT=1 docker build . -f python_component_build/Dockerfile -t openmpf_python_component_build
DOCKER_BUILDKIT=1 docker build . -f python_executor/Dockerfile -t openmpf_python_executor
```


How to use this image
===========================
The following steps assume you are using the default project structure for OpenMPF Python components. Documentation
for Python components can be found [here](https://openmpf.github.io/docs/site/Python-Batch-Component-API). 

The [EastTextDetection component](https://github.com/openmpf/openmpf-components/tree/master/python/EastTextDetection) 
is a good example of a Dockerized Python component.

### Create a Dockerfile in your Python component project
You should put your Dockerfile in the component project's top level directory. For example:
```
MyFaceDetection
├── Dockerfile
├── my_face_detection
│   ├── __init__.py
│   └── my_face_detection.py
├── plugin-files
│   └── descriptor
│       └── descriptor.json
└── setup.py
```

The minimal Dockerfile is:
```dockerfile
# In first stage of the build we extend the openmpf_python_component_build base image.
FROM openmpf_python_component_build:latest as build_component

# If your component has external dependencies, you would add the commands necessary to download 
# or build the dependencies here. Adding the dependencies prior the copying in your source code 
# allows you to take advantage of the Docker build cache to avoid re-installing the dependencies 
# every time your source code changes.
# e.g. RUN pip install --no-cache-dir 'opencv-python>=3.4.7' 'tensorflow>=2.1.0'

# Copy in your source code
COPY . .

# Install your component in to your component's virtualenv (located at $COMPONENT_VIRTUALENV).
# The [install-component.sh](../python_component_build/scripts/install-component.sh) 
# script is provided by the openmpf_python_component_build base image.
RUN install-component.sh

# You optionally may want to run unit tests here, or wherever is appropriate for your Dockerfile. 
# The [EastTextDetection component's Dockerfile](https://github.com/openmpf/openmpf-components/blob/master/python/EastTextDetection/Dockerfile) 
# shows one way of setting up unit tests, but you can do it in whatever way you see fit. 


# In the second stage of the build we extend the openmpf_python_executor base image
FROM openmpf_python_executor:latest


# If your component has runtime dependencies that are not pip packages, 
# you should install them here. Adding the dependencies prior to copying your component's 
# build artifacts allows you to take advantage of the Docker build cache to avoid re-installing
# the dependencies every time your source code changes.

# Copy your component's virtualenv from the build stage.
# The install-component.sh script from the build stage installed 
# your plugin code and its pip dependencies in the 
# virtualenv located at $COMPONENT_VIRTUALENV.
COPY --from=build_component $COMPONENT_VIRTUALENV $COMPONENT_VIRTUALENV

# This copies over any files in your plugin's plugin-files directory.
# Minimally, this will include your component's descriptor.
COPY --from=build_component $PLUGINS_DIR/MyFaceDetection $PLUGINS_DIR/MyFaceDetection

# Set the COMPONENT_LOG_NAME environment variable so that your component's log 
# file can be printed to standard out when running the image. 
ENV COMPONENT_LOG_NAME my-face-detection.log
```

Your Dockerfile may use more than the two stages shown above, but the final stage in the Dockerfile must be the
`FROM openmpf_python_executor:latest` stage.


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
