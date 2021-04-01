# syntax=docker/dockerfile:1.2

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2021 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2021 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################


ARG BUILD_REGISTRY
ARG BUILD_TAG=latest
FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} as openmpf_build


FROM centos:7 as common

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8


COPY --from=openmpf_build /usr/local/bin/python3.8 /usr/local/bin/python3.8-config \
    /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.8 /usr/local/bin/wheel \
    /usr/local/bin/

COPY --from=openmpf_build /usr/local/lib/python3.8 /usr/local/lib/python3.8

COPY --from=openmpf_build /usr/local/lib/libpython3.8.so.1.0 /usr/local/lib/libpython3.8.so.1.0

RUN cd /usr/local/bin; \
    ln --symbolic python3.8 python3; \
    ln --symbolic python3.8-config python3-config; \
    cd /usr/local/lib; \
    ln --symbolic libpython3.8.so.1.0 libpython3.8.so; \
    ln --symbolic /usr/local/lib/libpython3.8.so.1.0 /usr/lib64/libpython3.8.so.1.0;

# The Python headers are needed to build Python libararies with C extensions.
COPY --from=openmpf_build /usr/local/include/python3.8 /usr/local/include/python3.8

RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/var/cache/yum \
    yum update --assumeyes; \
    yum-config-manager --setopt=skip_missing_names_on_install=False --save; \
    yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes ffmpeg; \
    yum clean all;

ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

# Adding $COMPONENT_VIRTUALENV/bin to the front of $PATH persistently activates the virtualenv.
ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH


#########################################
FROM common as build

RUN python3 -m venv "$COMPONENT_VIRTUALENV"; \
    pip3 install --no-cache-dir --upgrade pip;

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python \
    pip3 install --no-cache-dir /tmp/python/api /tmp/python/component_util; \
    python3 -m unittest discover --verbose --buffer --start-directory /tmp/python/component_util

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY python/install-component.sh /scripts/


LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Builder" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"


#########################################
FROM common as executor

# Use mount and cp shell command because the docker COPY command resolves symlinks which then causes duplicate copies
# of the libraries to be added to the image.
RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libapr* libXext* \
        /usr/lib64;

# Component executor binary
COPY --from=openmpf_build /build-artifacts/install/bin/amq_detection_component \
                          $MPF_HOME/bin/amq_detection_component

# Component executor log config
COPY --from=openmpf_build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/

# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV PLUGINS_DIR $MPF_HOME/plugins


COPY docker-entrypoint.sh component-executor.py /scripts/

COPY cli_runner/mpf_cli_runner.py cli_runner/mpf_cli_runner_util.py cli_runner/mpf_python_runner.py \
     /scripts/cli_runner/

RUN ln --symbolic /scripts/cli_runner/mpf_cli_runner.py /usr/bin/runner

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]


LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"


#########################################
FROM executor as ssb

COPY --from=build $COMPONENT_VIRTUALENV $COMPONENT_VIRTUALENV

COPY --from=build /scripts/install-component.sh /scripts/

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR


LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Executor Single Stage Build (SSB)" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"


#########################################
FROM executor
