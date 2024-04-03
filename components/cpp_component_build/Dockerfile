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
FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} as openmpf_build


FROM ubuntu:20.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install --no-install-recommends -y \
        wget ca-certificates gnupg2 cmake make g++ libgtest-dev  liblog4cxx-dev libboost-dev \
        libavcodec58 libavformat58 libswscale5 libopenblas0-pthread liblapacke; \
    # Can't set up cuda repo at the beginning because it requires wget ca-certificates gnupg2
    wget -O- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub \
            | apt-key add -; \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64 /" \
        > /etc/apt/sources.list.d/cuda.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        cuda-minimal-build-11-4 libcudnn8-dev=8.2.4.15-1+cuda11.4 libcudnn8=8.2.4.15-1+cuda11.4 \
        libcublas-dev-11-4; \
    # OpenCV doesn't use the statically compiled CUDA libraries except for libcudart and they are relatively large.
    rm /usr/local/cuda/lib64/libcublasLt_static.a /usr/local/cuda/lib64/libcublas_static.a \
        /usr/lib/x86_64-linux-gnu/libcudnn*.a; \
    ln --symbolic /usr/bin/cmake /usr/bin/cmake3;

COPY --from=openmpf_build /opt/opencv-4.9.0 /opt/opencv-4.9.0

COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

# Normally components' CMakeList.txt file includes include(../ComponentSetup.cmake) but since that
# is outside of the components' build context we create it here.
RUN mkdir /home/mpf; echo 'find_package(mpfCMakeHelpers REQUIRED)' > /home/mpf/ComponentSetup.cmake

COPY --from=openmpf_build /build-artifacts/mpf-sdk-install/include /home/mpf/mpf-sdk-install/include
COPY --from=openmpf_build /build-artifacts/mpf-sdk-install/lib /home/mpf/mpf-sdk-install/lib

RUN echo '/opt/opencv-4.9.0/lib' > /etc/ld.so.conf.d/opencv.conf; \
    echo '/home/mpf/mpf-sdk-install/lib' > /etc/ld.so.conf.d/mpf.conf; \
    ldconfig

COPY cpp_component_build/scripts /scripts

ENV PATH /scripts:$PATH

ENV CMAKE_PREFIX_PATH /home/mpf/mpf-sdk-install/lib/cmake

ENV BUILD_DIR /home/mpf/component_build

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF C++ Component Builder" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-cpp-component-sdk" \
      org.label-schema.vendor="MITRE"
