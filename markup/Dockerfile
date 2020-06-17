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

# Docker COPY only preserves symlinks when copying an entire directory so we copy the files and their symlinks in to
# a temporary directory
RUN mkdir /root/copy_libs64 \
    && cp --preserve=links --no-dereference /build-artifacts/install/lib/libopencv* /root/copy_libs64/


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

RUN yum update --assumeyes; \
    yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes java-11-openjdk ffmpeg; \
    yum clean all; \
    rm -rf /var/cache/yum/*;

COPY --from=openmpf_build /root/copy_libs64 /usr/lib64/

COPY --from=openmpf_build /build-artifacts/install/lib/libmpfopencvjni.so /usr/lib64/

COPY --from=openmpf_build /build-artifacts/install/lib/libmpfDetectionComponentApi.so /usr/lib64/

ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/markup/*.jar $MPF_HOME/jars/

ENV ACTIVE_MQ_HOST activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MPF_LOG_PATH $MPF_HOME/share/logs
ENV THIS_MPF_NODE markup

WORKDIR $MPF_HOME/jars

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Markup" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf" \
      org.label-schema.vendor="MITRE"
