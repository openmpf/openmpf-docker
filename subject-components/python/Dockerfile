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
    apt-get install --no-install-recommends -y tini libgl1-mesa-glx libglib2.0-0 \
        wget ca-certificates gnupg2
    wget -O- 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xba6932366a755776' \
        | apt-key add -
    echo 'deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main' \
        > /etc/apt/sources.list.d/deadsnakes.list
    apt-get update
    apt-get install --no-install-recommends -y python3.12 python3.12-venv libpython3.12
    ln --symbolic /usr/bin/python3.12 /usr/local/bin/python3
eot

ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

# Adding $COMPONENT_VIRTUALENV/bin to the front of $PATH persistently activates the virtualenv.
ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH

#########################################
FROM common AS build

# The subject component executor depends on the python-qpid-proton pip package.
# python-qpid-proton requires a C compiler and the Python headers to be installed.
RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
<<eot
    apt-get update
    apt-get install --no-install-recommends -y gcc python3.12-dev
eot

RUN <<eot
    python3 -m venv "$COMPONENT_VIRTUALENV"
    pip config --site set global.no-cache-dir true
    pip install --upgrade pip
    pip install --upgrade setuptools
eot

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python,rw \
    pip3 install --no-cache-dir /tmp/python/api /tmp/python/component_util;

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/subject,target=/tmp/python,rw \
    pip3 install --no-cache-dir /tmp/python/api;

RUN --mount=from=openmpf_build,source=/build-artifacts/install/bin/subject_executor/requirements.txt,target=/tmp/requirements.txt \
    pip3 install -r /tmp/requirements.txt

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY install-component.sh /scripts/


#########################################
FROM common AS executor

ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/install/bin/subject_executor $MPF_HOME/bin/subject_executor

ENV PYTHONUNBUFFERED 1

ENV PLUGINS_DIR $MPF_HOME/plugins

ENV ACTIVE_MQ_HOST workflow-manager

ENV COMPONENT_LANGUAGE python

# Using tini here is equivalent to starting the container with the --init flag, except that users
# do not need to remember to add the flag.
ENTRYPOINT ["tini", "-v", "--", "python", "/opt/mpf/bin/subject_executor/__main__.py"]
