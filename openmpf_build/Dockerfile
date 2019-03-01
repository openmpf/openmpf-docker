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

ARG BUILD_VERSION
ARG BUILD_DATE
ARG OPENMPF_SHA
ARG OPENMPF_COMPONENTS_SHA
ARG OPENMPF_CONTRIB_COMPONENTS_SHA
ARG OPENMPF_CPP_COMPONENT_SDK_SHA
ARG OPENMPF_JAVA_COMPONENT_SDK_SHA
ARG OPENMPF_PYTHON_COMPONENT_SDK_SHA
ARG OPENMPF_BUILD_TOOLS_SHA

FROM centos:7.4.1708 as openmpf_build
WORKDIR /home/mpf

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://github.com/openmpf" \
      org.label-schema.name="OpenMPF Build Environment" \
      org.label-schema.version=$BUILD_VERSION \
      org.label-schema.build-date=$BUILD_DATE \
      openmpf-sha=$OPENMPF_SHA \
      openmpf-components-sha=$OPENMPF_COMPONENTS_SHA \
      openmpf-contrib-components-sha=$OPENMPF_CONTRIB_COMPONENTS_SHA \
      openmpf-cpp-component-sdk-sha=$OPENMPF_CPP_COMPONENT_SDK_SHA \
      openmpf-java-component-sdk-sha=$OPENMPF_JAVA_COMPONENT_SDK_SHA \
      openmpf-python-component-sdk-sha=$OPENMPF_PYTHON_COMPONENT_SDK_SHA \
      openmpf-build-tools-sha=$OPENMPF_BUILD_TOOLS_SHA

################################################################################
# Initial Setup                                                                #
################################################################################

# Create the "mpf" user:
RUN useradd -u 376 -U -d /home/mpf -ms /bin/bash -G wheel -p mpf mpf

################################################################################
# Prepare Entrypoint                                                           #
################################################################################

COPY docker-entrypoint.sh /home/mpf
RUN dos2unix -q /home/mpf/docker-entrypoint.sh
ENTRYPOINT ["/home/mpf/docker-entrypoint.sh"]
