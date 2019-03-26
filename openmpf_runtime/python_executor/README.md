How to use this image
===========================

You can either create a Dockerfile in your Python component project or use this image directly using a bind mount.


Create a Dockerfile in your Python component project
----------------------------
The minimal Dockerfile is:
```dockerfile
FROM python_executor:latest

COPY . /home/mpf/component_src/

RUN /home/mpf/scripts/install-component.sh
```

However, it is recommended that you set up your environment and install any dependencies prior to the 
`COPY . /home/mpf/component_src/` command. Putting steps before `COPY` allows you to avoid re-running those commands
every time you modify your source code. For example:
```dockerfile
FROM python_executor:latest

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
`docker build -t <component_name> <component_path>`


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
    -v "<component_path>:/home/mpf/component_src" \
    python_executor
```

