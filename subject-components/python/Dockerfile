# syntax=docker/dockerfile:1.4

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2024 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2024 The MITRE Corporation                                      #
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
FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} AS openmpf_build


FROM ubuntu:20.04 AS common

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
<<eot
    apt-get update
    apt-get upgrade -y
    apt-get install --no-install-recommends -y python3.8 python3.8-venv libpython3.8 tini \
        libgl1-mesa-glx libglib2.0-0
eot

ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

# Adding $COMPONENT_VIRTUALENV/bin to the front of $PATH persistently activates the virtualenv.
ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH

#########################################
FROM common AS build

RUN <<eot
    python3 -m venv "$COMPONENT_VIRTUALENV"
    pip config --site set global.no-cache-dir true
eot

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python \
    pip3 install --no-cache-dir /tmp/python/api /tmp/python/component_util;

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/subject,target=/tmp/python \
    pip3 install --no-cache-dir /tmp/python/api;

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY install-component.sh /scripts/

FROM common AS copy_libs

RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/bin/subject_tracking_executor,target=/tmp/subject_tracking_executor \
    --mount=type=bind,from=openmpf_build,source=/scripts/copy_libs.sh,target=/tmp/copy_libs.sh \
    mkdir /libs-to-copy; \
    /tmp/copy_libs.sh /tmp/subject_tracking_executor /libs-to-copy /tmp/mpf-libs


#########################################
FROM common AS executor

COPY --from=copy_libs /libs-to-copy /usr/lib/x86_64-linux-gnu/

ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/install/bin/subject_tracking_executor \
                          $MPF_HOME/bin/subject_tracking_executor

ENV PYTHONUNBUFFERED 1

ENV PLUGINS_DIR $MPF_HOME/plugins

ENV ACTIVE_MQ_BROKER_URI failover:(tcp://workflow-manager:61616)?maxReconnectAttempts=13&startupMaxReconnectAttempts=21

ENV COMPONENT_LANGUAGE python

# Using tini here is equivalent to starting the container with the --init flag, except that users
# do not need to remember to add the flag.
ENTRYPOINT ["tini", "-v", "--", "/opt/mpf/bin/subject_tracking_executor"]
