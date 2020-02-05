# syntax=docker/dockerfile:experimental

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2019 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2019 The MITRE Corporation                                      #
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


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]


ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

RUN yum update --assumeyes; \
    yum install --assumeyes epel-release \
                https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    # libSM and libXrender packages are required for opencv-python
    yum install --assumeyes ffmpeg libSM libXrender python-pip; \
    yum clean all; \
    rm --recursive /var/cache/yum/*; \
    pip install --no-cache-dir --upgrade pip virtualenv; \
    virtualenv "$COMPONENT_VIRTUALENV";


# Use mount so the source files don't end up in image
RUN --mount=type=bind,from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python \
    "$COMPONENT_VIRTUALENV/bin/pip" install --no-cache-dir /tmp/python/api /tmp/python/component_util; \
    "$COMPONENT_VIRTUALENV/bin/python" /tmp/python/component_util/tests/__main__.py;


# Use mount and cp shell command because the docker COPY command resolves symlinks which then causes duplicate copies
# of the libraries to be added to the image.
RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libQtCore* libapr* libXext* \
        /usr/lib64;


# Component executor binary
COPY --from=openmpf_build /build-artifacts/install/bin/amq_detection_component $MPF_HOME/bin/amq_detection_component

# Component executor log config
COPY --from=openmpf_build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/


# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY python_executor/scripts /scripts

ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH

COPY docker-executor-entrypoint.py /scripts/docker-entrypoint.py

# Command used when this Dockerfile is extended by component's Dockerfile
ONBUILD ENTRYPOINT ["python", "/scripts/docker-entrypoint.py"]

# Command used when this Dockerfile is not extended. Source code must be bind-mounted to /home/mpf/component_src
ENTRYPOINT ["bash", "-c", "/scripts/install-component.sh && python /scripts/docker-entrypoint.py"]


LABEL org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"
