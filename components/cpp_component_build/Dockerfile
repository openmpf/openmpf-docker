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

FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

# Change override_install_langs because the centos:7 image sets this yum property to en_US.utf8
# which prevents other locales (including other English locales) from being installed with GCC.
RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/var/cache/yum \
    yum-config-manager --setopt=override_install_langs='' \
                       --setopt=skip_missing_names_on_install=False --save; \
    yum update --assumeyes; \
    yum-config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64; \
    yum install --assumeyes epel-release \
            https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            http://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm; \
    yum install --assumeyes  --nogpgcheck cmake3 make gcc gcc-c++ qt-devel log4cxx-devel \
            boost-devel ffmpeg-libs gtest-devel openblas-devel cuda-minimal-build-10-2 \
            libcublas-devel-10.2.2.89-1 libcudnn7-devel-7.6.5.33-1.cuda10.2; \
    yum clean all; \
    ln --symbolic cuda-10.2 /usr/local/cuda; \
    # OpenCV doesn't use the statically compiled CUDA libraries except for libcudart and they are relatively large.
    find /usr/local/cuda/lib64/ -name '*.a' -not -name 'libcudart_static.a' \
                                            -not -name 'libcudadevrt.a' -delete; \
    rm /usr/lib64/libcudnn*.a; \
    echo '/usr/local/cuda/lib64' >> /etc/ld.so.conf.d/cuda.conf; \
    ldconfig;

COPY --from=openmpf_build /opt/opencv-4.5.0 /opt/opencv-4.5.0

COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

# Normally components' CMakeList.txt file includes include(../ComponentSetup.cmake) but since that
# is outside of the components' build context we create it here.
RUN mkdir /home/mpf; echo 'find_package(mpfCMakeHelpers REQUIRED)' > /home/mpf/ComponentSetup.cmake

COPY --from=openmpf_build /build-artifacts/mpf-sdk-install/include /home/mpf/mpf-sdk-install/include
COPY --from=openmpf_build /build-artifacts/mpf-sdk-install/lib /home/mpf/mpf-sdk-install/lib

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
