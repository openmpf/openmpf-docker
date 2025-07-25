Overview
==================
The purpose of these images is to enable a developer to write a Python component for OpenMPF that can be encapsulated
within a Docker container. This isolates the execution environment from the rest of OpenMPF, thereby providing greater
freedom and portability. There are two types of executor base images: `openmpf_python_executor_ssb`
and `openmpf_python_executor`.

`openmpf_python_executor` is designed to work with `openmpf_python_component_build` in a multi-stage Docker
build. `openmpf_python_executor` and `openmpf_python_component_build` should be used if the component has any build time
dependencies (like compilers) that are not used at runtime.

`openmpf_python_executor_ssb` can be used when the component is pure Python and does not require any build time
dependencies. Some pip packages will attempt to compile C extensions during
`pip install`. If you are using one of these libraries, you will need to use
`openmpf_python_executor` and `openmpf_python_component_build`.

Both `openmpf_python_executor_ssb` and `openmpf_python_executor` will:

- Register your component with the Workflow Manager.
- Execute your code using the OpenMPF component executor binary.

Pull or build the base images
======================================================
Most developers will not need to build their own set of base images. Instead, they can pull them from
[Docker Hub](https://hub.docker.com/u/openmpf) as follows:

```bash
docker pull openmpf/openmpf_python_component_build:latest
docker pull openmpf/openmpf_python_executor:latest
docker pull openmpf/openmpf_python_executor_ssb:latest
```

Alternatively, these build steps assume that you've previously built the `openmpf_build` base image described
[here](https://github.com/openmpf/openmpf-docker/blob/master/README.md#create-the-openmpf-build-image):

```bash
cd /path/to/openmpf-docker/components
DOCKER_BUILDKIT=1 docker build . -f python/Dockerfile --target build -t openmpf_python_component_build
DOCKER_BUILDKIT=1 docker build . -f python/Dockerfile --target executor -t openmpf_python_executor
DOCKER_BUILDKIT=1 docker build . -f python/Dockerfile --target ssb -t openmpf_python_executor_ssb
```

How to use these images
===========================
The following steps assume you are using the default project structure for OpenMPF Python components. Documentation for
Python components can be found [here](https://openmpf.github.io/docs/site/Python-Batch-Component-API).

The [EastTextDetection component](https://github.com/openmpf/openmpf-components/tree/master/python/EastTextDetection)
is a good example of a Dockerized Python component.

### Create a Dockerfile in your Python component project

You should put your Dockerfile in the component project's top level directory. For example:

```
MyFaceDetection
├── Dockerfile
├── my_face_detection
│   ├── __init__.py
│   └── my_face_detection.py
├── plugin-files
│   └── descriptor
│       └── descriptor.json
├── setup.cfg
└── pyproject.toml
```

#### `openmpf_python_executor_ssb`

If you are using `openmpf_python_executor_ssb`, the minimal Dockerfile is as follows. Note that if you built your own
base images then you should omit the `openmpf/` prefix on the `FROM` line.

```dockerfile
FROM openmpf/openmpf_python_executor_ssb:latest as build_component

# If your component has external dependencies, you would add the commands necessary to download
# or install the dependencies here. Adding the dependencies prior the copying in your source code
# allows you to take advantage of the Docker build cache to avoid re-installing the dependencies
# every time your source code changes.
# e.g. RUN pip3 install --no-cache-dir 'opencv-python>=4.4.0' 'tensorflow>=2.1.0'

# `--mount=target=.,readwrite` will bind-mount the root of the build context on to the current
# working directory, which is set to $SRC_DIR in the base image. Written data will be discarded.
# The [install-component.sh](./install-component.sh) script will install your component in to your
# component's virtualenv (located at $COMPONENT_VIRTUALENV). It is provided by the
# openmpf_python_executor_ssb base image.
# You also may want run unit tests in this step.
# The [EastTextDetection component's Dockerfile](https://github.com/openmpf/openmpf-components/blob/master/python/EastTextDetection/Dockerfile)
# shows one way of setting up unit tests.
RUN --mount=target=.,readwrite install-component.sh
```

#### `openmpf_python_executor`

If you are using `openmpf_python_executor` the minimal Dockerfile is as follows. Note that if you built your own base
images then you should omit the `openmpf/` prefix on the `FROM` lines.

```dockerfile
# In first stage of the build we extend the openmpf_python_component_build base image.
FROM openmpf/openmpf_python_component_build:latest as build_component

# If your component has external dependencies, you would add the commands necessary to download
# or build the dependencies here. Adding the dependencies prior the copying in your source code
# allows you to take advantage of the Docker build cache to avoid re-installing the dependencies
# every time your source code changes.
# e.g. RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*
# e.g. RUN pip3 install --no-cache-dir 'opencv-python>=4.4.0' 'tensorflow>=2.1.0'

# Copy in your source code
COPY . .

# Install your component in to your component's virtualenv (located at $COMPONENT_VIRTUALENV).
# The [install-component.sh](../python_component_build/scripts/install-component.sh)
# script is provided by the openmpf_python_component_build base image.
RUN install-component.sh

# You optionally may want to run unit tests here, or wherever is appropriate for your Dockerfile.
# The [EastTextDetection component's Dockerfile](https://github.com/openmpf/openmpf-components/blob/7145929319ff18c2b5957a3b7f88e4a04fcf3670/python/EastTextDetection/Dockerfile)
# shows one way of setting up unit tests, but you can do it in whatever way you see fit.


# In the second stage of the build we extend the openmpf_python_executor base image
FROM openmpf/openmpf_python_executor:latest


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

```bash
docker run \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    <component_name>
```
