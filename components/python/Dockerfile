# syntax=docker/dockerfile:1.2

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2023 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2023 The MITRE Corporation                                      #
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
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install --no-install-recommends -y \
        python3.8 python3.8-venv libpython3.8 \
        # Required for opencv-python
        libglib2.0-0 libgl1-mesa-glx;

COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

ENV MPF_HOME /opt/mpf

ENV COMPONENT_VIRTUALENV $MPF_HOME/plugin-venv

# Adding $COMPONENT_VIRTUALENV/bin to the front of $PATH persistently activates the virtualenv.
ENV PATH $COMPONENT_VIRTUALENV/bin:/scripts:$PATH


#########################################
FROM common AS build_api

RUN python3 -m venv "$COMPONENT_VIRTUALENV"; \
    pip config --site set global.no-cache-dir true; \
    pip install --upgrade setuptools;

RUN --mount=from=openmpf_build,source=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection,target=/tmp/python \
    pip3 install --no-cache-dir /tmp/python/api /tmp/python/component_util; \
    python3 -m unittest discover --verbose --buffer --start-directory /tmp/python/component_util/tests

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
# Install and test the text splitter in a different stage so that the dependencies don't end up in
# the base image for all Python components.
FROM build_api AS build_text_splitter

COPY --from=openmpf_build \
    /home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/nlp_text_splitter \
    /home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/nlp_text_splitter

WORKDIR /home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/nlp_text_splitter

RUN ./install.sh -i wtp-canine-s-1l

RUN python tests/test_text_splitter.py

# Remove the tests directory so that the entire nlp_text_splitter directory can be copied without
# also including the tests in the next stage.
RUN rm -r tests


#########################################
FROM build_api AS build

# Copy the text splitter source code in to the image so that components can choose to install it in
# their Docker images.
COPY --from=build_text_splitter \
    /home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/nlp_text_splitter \
    /home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/nlp_text_splitter


#########################################
FROM common AS executor

# Use mount and cp shell command because the docker COPY command resolves symlinks which then causes duplicate copies
# of the libraries to be added to the image.
RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libapr* libactivemq-cpp* \
        /usr/lib/x86_64-linux-gnu;

# Component executor binary
COPY --from=openmpf_build /build-artifacts/install/bin/amq_detection_component \
                          $MPF_HOME/bin/amq_detection_component

# Component executor log config
COPY --from=openmpf_build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/

COPY --from=openmpf_build /scripts/* /scripts/

# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV PLUGINS_DIR $MPF_HOME/plugins

COPY docker-entrypoint.sh component-executor.py component_registration.py /scripts/

COPY cli_runner/*.py /scripts/cli_runner/

RUN ln --symbolic /scripts/cli_runner/mpf_cli_client.py /usr/bin/runner

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]


LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-python-component-sdk" \
      org.label-schema.vendor="MITRE"

#########################################
FROM executor AS ssb

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
