# Extract tar in separate container to avoid bloat in final image since we only need some of the files.
FROM centos:7 as extract_tar

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

RUN yum install -y epel-release \
    # libSM and libXrender packages are required for opencv-python
    && yum install -y python-pip libSM libXrender \
    && yum clean all \
    && rm -rf /var/cache/yum/*

# Virtualenv must be in exact same directory as in the final image because virtualenvs are not relocatable.
RUN pip install --no-cache-dir --upgrade pip virtualenv \
    && virtualenv "$COMPONENT_VIRTUALENV"

WORKDIR /root/install_files
COPY install.tar .

RUN tar -xf install.tar \
        # Python component SDK wheels
        ./python/wheelhouse \
        # Component executor binary
        ./bin/amq_detection_component \
        # Component executor log config
        ./config/Log4cxxConfig.xml \
        # Libraries required for component executor
        './lib/liblog4cxx*' './lib/libactivemq-cpp*' './lib/libQtCore*' './lib/libapr*' './lib/libXext*' \
    && rm install.tar \
    # Install MPF .whl files here so that only the expanded contents of the whl file are present in final image.
    && "$COMPONENT_VIRTUALENV/bin/pip" --no-cache-dir install python/wheelhouse/* \
    && rm -rf python



FROM centos:7

# Copy in opencv-python dependencies
COPY --from=extract_tar /usr/lib64/libSM.so* /usr/lib64/libICE.so* /usr/lib64/libXrender.so* /usr/lib64/libX11* \
                        /usr/lib64/libxcb.so* /usr/lib64/libXau.so* /usr/lib64/

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

WORKDIR $MPF_HOME
COPY --from=extract_tar /root/install_files/ $MPF_HOME
COPY --from=extract_tar $COMPONENT_VIRTUALENV $COMPONENT_VIRTUALENV

ENV MPF_LOG_PATH $MPF_HOME/share/logs
ENV THIS_MPF_NODE python_executor
# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

COPY scripts /home/mpf/scripts
COPY docker-entrypoint.py /home/mpf/

# Command used when this Dockerfile is extended by component's Dockerfile
ONBUILD ENTRYPOINT ["python", "/home/mpf/docker-entrypoint.py"]

# Command used when this Dockerfile is not extended. Source code must be bind-mounted to /home/mpf/component_src
ENTRYPOINT ["bash", "-c", "/home/mpf/scripts/install-component.sh && python /home/mpf/docker-entrypoint.py"]


