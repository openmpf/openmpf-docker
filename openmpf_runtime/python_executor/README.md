Overview
==================
The purpose of this image is to enable a developer to write a Python component for OpenMPF that can be encapsulated
within a Docker container. This isolates the execution environment from the rest of OpenMPF,
thereby providing greater freedom and portability.

This image will:

- Register your component with the Workflow Manager.
- Execute your code using the OpenMPF component executor binary.
- Tail log files so that they appear in the terminal window where you ran `docker run ..`
  to start your component container.

You have two options:

1\. Create a Dockerfile in your Python component project.
  - Do this if you need to install custom dependencies in the image to run your component.
  - This Dockerfile extends from the base `openmpf_python_executor` image.
  - This approach will pull in your component source code via the Docker build context
    with a `COPY` command when you run `docker build …`.
  - This approach will install your component in the image at build time.
    In the end you will have a Docker image for your component.

2\. Use the base `openmpf_python_executor` image without your own Dockerfile.
  - This is a simpler option if you don’t need to install custom dependencies.
  - This approach will pull in your component source from a bind mount
    that you must specify when you execute `docker run …`.
  - This approach will install your component in the container as part of the Docker entry point at runtime.
    Your code only ever exists in the container. This approach will not generate a Docker image for your component.
  - You can think of the `openmpf_python_executor` image as a tool that you use to build and run your code.

Each approach installs your component the same way,
but the former does it at build time and the latter does it at runtime.


How to build the `openmpf_python_executor` base image
======================================================
```bash
cd /path/to/openmpf-docker/openmpf_runtime
docker build . -f python_executor/Dockerfile -t openmpf_python_executor
```


How to use this image
===========================
You can either create a Dockerfile in your Python component project or use this image directly using a bind mount.
> **NOTE:** The following `docker run ...` commands use the default values for the `WFM_USER` and `WFM_PASSWORD`.
> If the default admin user has been changed, you will need to change `WFM_USER` and `WFM_PASSWORD` to the credentials
> that an admin user uses to log in to the Workflow Manager web UI.

Create a Dockerfile in your Python component project
----------------------------
You should put your Dockerfile in the component project's top level directory. For example:
```
PythonOcvComponent
├── Dockerfile
├── setup.py
├── ocv_component
│   ├── ocv_component.py
│   ├── __init__.py
│   └── models
│       ├── animal_names.txt
│       ├── animal_network.bin
│       └── models.ini
└── plugin-files
    └── descriptor
        └── descriptor.json
```


The minimal Dockerfile is:
```dockerfile
FROM openmpf_python_executor:latest

COPY . /home/mpf/component_src/

RUN /home/mpf/scripts/install-component.sh
```

However, it is recommended that you set up your environment and install any dependencies prior to the
`COPY . /home/mpf/component_src/` command. Putting steps before `COPY` allows you to avoid re-running those commands
every time you modify your source code. For example:
```dockerfile
FROM openmpf_python_executor:latest

# Replace with your actual dependencies
RUN "$COMPONENT_VIRTUALENV/bin/pip" install --no-cache-dir 'opencv-python>=3.3' 'tensorflow'

COPY . /home/mpf/component_src/

RUN /home/mpf/scripts/install-component.sh

# Only required if you want your component's log file to be written to stdout.
# Can also be passed in using -e during `docker run ...`
# Replace with your component's log file name
ENV COMPONENT_LOG_NAME python-ocv-test.log
```


### Build image for your component
Run the following command, replacing `<component_name>` with the name of your component and `<component_path>` with the
path on the host file system to the component projects's top level directory:
```bash
docker build -t <component_name> <component_path>
```


### Run your component
1. Start OpenMPF
2. Run the following command replacing `<component_name>` with the value provided in the build step.
```bash
docker run --rm -it \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    <component_name>
```


Use this image without your own Dockerfile
---------------------------
1. Start OpenMPF
2. Run the following command replacing `<component_log_name>` with the name of the file that your component logs to
   and `<component_path>` with the path on host file system to the component project's top level directory.
```bash
docker run --rm -it \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpf_adm \
    -e COMPONENT_LOG_NAME=<component_log_name> \
    -v "<component_path>:/home/mpf/component_src:ro" \
    openmpf_python_executor
```


How to use this image with a non-Docker deployment of OpenMPF
----------------------------------------------
Additional command line arguments need to be added to the `docker run ...` command in order to use
`openmpf_python_executor` with a non-Docker deployment.

If you are using your own Dockerfile, to start your component run the following command replacing
`<activemq_hostname>`, `<wfm_base_url>`, and `<component_name>` with appropriate values.
```bash
docker run --rm -it \
    --network host \
    -e ACTIVE_MQ_HOST=<activemq_hostname> \
    -e WFM_BASE_URL=<wfm_base_url> \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
    -v "$MPF_HOME/share:/opt/mpf/share" \
    <component_name>
```
As an example, if you are running ActiveMQ and Workflow Manager on your local machine and you want to run the
`python_ocv_component` component, you would run the following command.
```bash
docker run --rm -it \
    --network host \
    -e ACTIVE_MQ_HOST=localhost \
    -e WFM_BASE_URL=http://localhost:8080/workflow-manager \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
    -v "$MPF_HOME/share:/opt/mpf/share" \
    python_ocv_component
```

If you are not using your own Dockerfile the command would be:
```bash
docker run --rm -it \
    --network host \
    -e ACTIVE_MQ_HOST=<activemq_hostname> \
    -e WFM_BASE_URL=<wfm_base_url> \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    -e COMPONENT_LOG_NAME=<component_log_name> \
    -v "<component_path>:/home/mpf/component_src:ro" \
    -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
    -v "$MPF_HOME/share:/opt/mpf/share" \
    openmpf_python_executor
```
