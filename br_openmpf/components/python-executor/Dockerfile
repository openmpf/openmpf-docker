
FROM br-openmpf-build as openmpf-build


FROM centos:7 as init

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

RUN yum install --assumeyes epel-release; \
    yum install --assumeyes  python-pip; \
    yum clean all; \
    rm --recursive /var/cache/yum/*; \
    pip install --no-cache-dir --upgrade pip virtualenv; \
    # Virtualenv must be in exact same directory as in the final image because virtualenvs are not relocatable.
    virtualenv "$COMPONENT_VIRTUALENV";


# Install MPF .whl files here so that only the expanded contents of the whl file are present in final image.
COPY --from=openmpf-build /build-artifacts/install/python/ /tmp/python
RUN "$COMPONENT_VIRTUALENV/bin/pip" install --no-cache-dir --no-index --find-links /tmp/python/wheelhouse \
    /tmp/python/wheelhouse/*

# Docker COPY only preserves symlinks when copying an entire directory so we copy the files and their symlinks in to
# a temporary directory.
COPY --from=openmpf-build /build-artifacts/install/lib /tmp/mpf-libs

RUN mkdir /copy_libs64; \
    cd /tmp/mpf-libs; \
    # Libraries built in openmpf-build that required for component executor
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libQtCore* libapr* libXext* \
        /copy_libs64;


#################
FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN yum install --assumeyes --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
        # libSM and libXrender packages are required for opencv-python
        yum install --assumeyes ffmpeg libSM libXrender; \
        yum clean all; \
        rm -rf /var/cache/yum/*;

COPY --from=init /copy_libs64 /usr/lib64/

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

# Component executor binary
COPY --from=openmpf-build /build-artifacts/install/bin/amq_detection_component $MPF_HOME/bin/amq_detection_component

# Component executor log config
COPY --from=openmpf-build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/

COPY --from=init $COMPONENT_VIRTUALENV $COMPONENT_VIRTUALENV

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

