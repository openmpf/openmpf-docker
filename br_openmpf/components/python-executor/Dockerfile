# syntax=docker/dockerfile:experimental


FROM br-openmpf-build as openmpf-build


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]


ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

RUN yum install --assumeyes --nogpgcheck epel-release \
            https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    # libSM and libXrender packages are required for opencv-python
    yum install --assumeyes ffmpeg libSM libXrender python-pip; \
    yum clean all; \
    rm --recursive /var/cache/yum/*; \
    pip install --no-cache-dir --upgrade pip virtualenv; \
    virtualenv "$COMPONENT_VIRTUALENV";


# Use mount so the .whl files don't end up in image
RUN --mount=type=bind,from=openmpf-build,source=/build-artifacts/install/python,target=/tmp/python \
    "$COMPONENT_VIRTUALENV/bin/pip" install --no-cache-dir --no-index --find-links /tmp/python/wheelhouse \
            /tmp/python/wheelhouse/*

# Use mount and cp shell command because docker COPY resolves symlinks which will end up duplicate copies the libraries.
RUN --mount=type=bind,from=openmpf-build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libQtCore* libapr* libXext* \
        /usr/lib64;


# Component executor binary
COPY --from=openmpf-build /build-artifacts/install/bin/amq_detection_component $MPF_HOME/bin/amq_detection_component

# Component executor log config
COPY --from=openmpf-build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/


# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY python-executor/scripts /scripts

ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH

COPY docker-executor-entrypoint.py /scripts/docker-entrypoint.py

# Command used when this Dockerfile is extended by component's Dockerfile
ONBUILD ENTRYPOINT ["python", "/scripts/docker-entrypoint.py"]

# Command used when this Dockerfile is not extended. Source code must be bind-mounted to /home/mpf/component_src
ENTRYPOINT ["bash", "-c", "/scripts/install-component.sh && python /scripts/docker-entrypoint.py"]

