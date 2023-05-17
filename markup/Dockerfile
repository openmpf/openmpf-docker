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
        openjdk-17-jre-headless wget \
        libavcodec58 libavformat58 libswscale5;

COPY --from=openmpf_build /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /usr/local/bin/

# Use mount and cp shell command because the docker COPY command resolves symlinks which then
# causes duplicate copies of the libraries to be added to the image.
RUN --mount=type=bind,from=openmpf_build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    cp --preserve=links --no-dereference \
        libopencv* libopenblas* libgfortran* libquadmath* libheif* libde265* \
        /usr/lib/x86_64-linux-gnu;

COPY --from=openmpf_build /usr/share/fonts/google-noto-emoji /usr/share/fonts/google-noto-emoji

COPY --from=openmpf_build /build-artifacts/install/lib/libmpfopencvjni.so \
                          /usr/lib/x86_64-linux-gnu/

COPY --from=openmpf_build /build-artifacts/install/lib/libmpfDetectionComponentApi.so \
                          /usr/lib/x86_64-linux-gnu

ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/markup/*.jar $MPF_HOME/jars/

ENV ACTIVE_MQ_HOST activemq
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
