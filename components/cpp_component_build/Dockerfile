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

# Change config because the centos:7 image sets this yum property to en_US.utf8 which prevents other locales
# (including other English locales) from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save; \
    yum update --assumeyes; \
    yum install --assumeyes epel-release \
            https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg gtest-devel; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

COPY --from=openmpf_build /opt/opencv-3.4.7 /opt/opencv-3.4.7

# Normally components' CMakeList.txt file includes include(../ComponentSetup.cmake) but since that is outside of the
# components' build context we create it here.
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
