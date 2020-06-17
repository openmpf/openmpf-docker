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



RUN yum update --assumeyes; \
    yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes ffmpeg; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

ENV MPF_HOME /opt/mpf

WORKDIR $MPF_HOME

# Use mount and cp shell command because the docker COPY command resolves symlinks which then causes duplicate copies
# of the libraries to be added to the image.
RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libapr* libXext* \
        /usr/lib64;

# component executor binary
COPY --from=openmpf_build /build-artifacts/install/bin/amq_detection_component $MPF_HOME/bin/amq_detection_component

# component executor log config
COPY --from=openmpf_build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/


ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV PYTHONUNBUFFERED 1

ENV BUILD_DIR /home/mpf/component_build

ENV PLUGINS_DIR $MPF_HOME/plugins

COPY docker-executor-entrypoint.py /scripts/docker-entrypoint.py

ENTRYPOINT ["python3", "/scripts/docker-entrypoint.py"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF C++ Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-cpp-component-sdk" \
      org.label-schema.vendor="MITRE"
