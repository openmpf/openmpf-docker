# syntax=docker/dockerfile:experimental

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
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

ENV LANG en_US.UTF-8

# Disable Python bytecode generation because it was causing build cache issues. It may slightly increase start up
# time, but once everything is imported, there is no difference in performance. If the bytecode files were critical,
# it is unlikely that the official Python Docker images would explicitly delete them. It also saves 86MB of space.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_COMPILE=0

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


ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH

RUN yum update --assumeyes; \
    yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes ffmpeg; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

RUN python3 -m venv "$COMPONENT_VIRTUALENV"; \
    pip3 install --no-cache-dir --upgrade pip;


# Use mount so the source files don't end up in image
RUN --mount=type=bind,from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python \
    pip3 install --no-cache-dir /tmp/python/api /tmp/python/component_util; \
    python3 -m unittest discover --verbose --buffer --start-directory /tmp/python/component_util

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

COPY python_component_build/scripts /scripts

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Builder" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"
