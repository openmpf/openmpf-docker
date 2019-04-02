How to build the openmpf_python_executor base image
======================================================
```bash
cd /path/to/openmpf-docker/openmpf_runtime
docker build . -f python_executor/Dockerfile -t openmpf_python_executor
```


How to use this image
===========================

You can either create a Dockerfile in your Python component project or use this image directly using a bind mount.

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
2. Run the following command replacing `<wfm_admin_user>`, `<wfm_password>`, and `<component_name>` 
   with appropriate values. `<component_name>` must match the value provided in the build step.
```bash
docker run --rm -it \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=<wfm_admin_user> \
    -e WFM_PASSWORD=<wfm_password> \
    <component_name>
```


Use this image without your own Dockerfile
---------------------------
1. Start OpenMPF 
2. Run the following command replacing `<wfm_admin_user>`, `<wfm_password>`, `<component_log_name>`, and 
   `<component_path>` with appropriate values. `<component_path>` is the path on host file system to the component 
   project's top level directory. `<component_log_name>` is name of the file that your component logs to.
```bash
docker run --rm -it \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=<wfm_admin_user> \
    -e WFM_PASSWORD=<wfm_password> \
    -e COMPONENT_LOG_NAME=<component_log_name> \
    -v "<component_path>:/home/mpf/component_src:ro" \
    openmpf_python_executor
```


How to use this image with a non-Docker deployment of OpenMPF
----------------------------------------------
Additional command line arguments need to be added to the `docker run ...` command in order to use 
openmpf_python_executor with a non-Docker deployment.

If you are using your own Dockerfile, to start your component run the following command replacing 
`<activemq_hostname>`, `<wfm_base_url>`, `<wfm_admin_user>`, `<wfm_password>`, and `<component_name>` with
appropriate values.
```bash
docker run --rm -it \
    --network host \
    -e ACTIVE_MQ_HOST=<activemq_hostname> \
    -e WFM_BASE_URL=<wfm_base_url> \
    -e WFM_USER=<wfm_admin_user> \
    -e WFM_PASSWORD=<wfm_password> \
    -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
    -v "$MPF_HOME/share:/opt/mpf/share"
    <component_name>
```
As an example, if you are running ActiveMQ and Workflow Manager on your local machine and you want to run the 
`python_ocv_component` component, you would run the following command.
```bash
docker run --rm -it \
    --network host \
    -e ACTIVE_MQ_HOST=localhost \
    -e WFM_BASE_URL=http://localhost:8080/workflow-manager \
    -e WFM_USER=my_admin_user \
    -e WFM_PASSWORD=my_admin_password \
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
    -e WFM_USER=<wfm_admin_user> \
    -e WFM_PASSWORD=<wfm_password> \
    -e COMPONENT_LOG_NAME=<component_log_name> \
    -v "$component_dir:/home/mpf/component_src:ro" \
    -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
    -v "$MPF_HOME/share:/opt/mpf/share" \
    openmpf_python_executor
```
