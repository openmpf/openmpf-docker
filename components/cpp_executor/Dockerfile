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

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install --no-install-recommends -y wget ca-certificates gnupg2; \
    # Can't set up cuda repo at the beginning because it requires wget ca-certificates gnupg2
    wget -O- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub \
            | apt-key add -; \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64 /" \
        > /etc/apt/sources.list.d/cuda.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends cuda-cudart-11-4;


COPY --from=openmpf_build \
    /usr/local/bin/python3.12 /usr/local/bin/python3.12-config \
    /usr/local/bin/pip3.12 /usr/local/bin/pip3 \
    /usr/local/bin/

COPY --from=openmpf_build /usr/local/lib/python3.12 /usr/local/lib/python3.12

COPY --from=openmpf_build /usr/local/lib/libpython3.12.so.1.0 /usr/local/lib/

RUN <<eot
    cd /usr/local/bin
    ln --symbolic python3.12 python3
    ln --symbolic python3.12-config python3-config
    cd /usr/local/lib
    ln --symbolic libpython3.12.so.1.0 libpython3.12.so
    ln --symbolic /usr/local/lib/libpython3.12.so.1.0 /lib/x86_64-linux-gnu/libpython3.12.so.1.0
eot

COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

# Environment variables required by nvidia runtime.
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

ENV MPF_HOME=/opt/mpf

WORKDIR $MPF_HOME


FROM common AS copy_libs

RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/bin/amq_detection_component,target=/tmp/amq_detection_component \
    --mount=type=bind,from=openmpf_build,source=/scripts/copy_libs.sh,target=/tmp/copy_libs.sh \
    mkdir /libs-to-copy; \
    /tmp/copy_libs.sh /tmp/amq_detection_component /libs-to-copy /tmp/mpf-libs


FROM common

COPY --from=copy_libs /libs-to-copy /usr/lib/x86_64-linux-gnu/

# component executor binary
COPY --from=openmpf_build /build-artifacts/install/bin/amq_detection_component \
                          $MPF_HOME/bin/amq_detection_component

# component executor log config
COPY --from=openmpf_build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/

COPY --from=openmpf_build /build-artifacts/install/lib/mpf_cpp_sdk.cpython-312-x86_64-linux-gnu.so \
                          /usr/lib/python3.12/lib-dynload

COPY --from=openmpf_build /scripts/* /scripts/

ENV MPF_LOG_PATH=$MPF_HOME/share/logs

ENV PYTHONUNBUFFERED=1

ENV BUILD_DIR=/home/mpf/component_build

ENV PLUGINS_DIR=$MPF_HOME/plugins


COPY docker-entrypoint.sh component-executor.py /scripts/

COPY cli_runner/*.py cli_runner/Log4cxxConfig.xml /scripts/cli_runner/

RUN ln --symbolic /scripts/cli_runner/mpf_cli_client.py /usr/bin/runner

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF C++ Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-cpp-component-sdk" \
      org.label-schema.vendor="MITRE"
