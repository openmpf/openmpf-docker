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

# The centos:7 image sets this yum property to en_US.utf8 which prevents other locales (including other Engish locales)
# from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save

RUN yum install -y epel-release \
    && yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && yum install -y cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg gtest-devel \
    && yum clean all \
    && rm -rf /var/cache/yum/*

COPY --from=openmpf_build /opt/opencv-3.3.0 /opt/

# Normally components' CMakeList.txt file includes include(../ComponentSetup.cmake) but since that is outside of the
# components' build context we create it here.
RUN mkdir -p /home/mpf && echo 'find_package(mpfCMakeHelpers REQUIRED)' > /home/mpf/ComponentSetup.cmake

ADD build_artifacts/mpf-sdk-install.tar.gz /home/mpf/

COPY cpp-component-build/scripts /home/mpf/scripts

ENV PATH /home/mpf/scripts:$PATH

ENV CMAKE_PREFIX_PATH /home/mpf/mpf-sdk-install/lib/cmake

ENV BUILD_DIR /home/mpf/component_build

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR


LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF C++ Component Builder" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE" \
      org.label-schema.version=$BUILD_TAG
