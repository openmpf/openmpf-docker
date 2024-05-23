# syntax=docker/dockerfile:1.4

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
        openjdk-17-jre-headless libtcnative-1 file mediainfo wget ca-certificates \
        python3.8 python3-pip;


RUN wget --directory-prefix /scripts \
        https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh; \
    chmod +x /scripts/wait-for-it.sh;


COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

COPY --from=openmpf_build /usr/local/bin/pngdefry /usr/local/bin/pngdefry

COPY --from=openmpf_build /build-artifacts/mpf-scripts /home/mpf/mpf-scripts

# Make sure mpf-scripts is not globally installed and that the mpf command in not on the $PATH
RUN mkdir --parents /home/mpf/mpf-scripts-install; \
    pip3 install --no-cache --target /home/mpf/mpf-scripts-install /home/mpf/mpf-scripts

COPY --from=openmpf_build /scripts/* /scripts/

ENV MPF_HOME /opt/mpf

ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/workflow-manager/WEB-INF/jni-libs


FROM common AS copy_libs

COPY --from=openmpf_build /build-artifacts/workflow-manager /build-artifacts/workflow-manager

RUN <<eot
    cd /build-artifacts/workflow-manager/WEB-INF
    mv jni-libs tmp-jni-libs
    mkdir jni-libs
    mv tmp-jni-libs/libmpfopencvjni.so jni-libs/
    /scripts/copy_libs.sh jni-libs/libmpfopencvjni.so jni-libs tmp-jni-libs
    rm -r tmp-jni-libs
eot


FROM common

COPY --from=copy_libs /build-artifacts/workflow-manager $MPF_HOME/workflow-manager

ENV REDIS_HOST=redis
ENV THIS_MPF_NODE=workflow-manager
ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV PATH=$PATH:$MPF_HOME/bin
# Default for JDBC configuration. Can be overridden at runtime.
ENV JDBC_URL=jdbc:postgresql://db:5432/mpf
ENV POSTGRES_USER=mpf
ENV POSTGRES_PASSWORD=password
ENV CLASSPATH=$MPF_HOME/workflow-manager/WEB-INF/classes:$MPF_HOME/workflow-manager/WEB-INF/lib/*
ENV spring_profiles_active=docker

EXPOSE 8080 8443

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
COPY mpf-users.sh /usr/local/bin/mpf-users

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Workflow Manager" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf" \
      org.label-schema.vendor="MITRE"

ARG BUILD_VERSION
ENV MPF_VERSION=$BUILD_VERSION
