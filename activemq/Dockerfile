# syntax=docker/dockerfile:1.2

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2022 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2022 The MITRE Corporation                                      #
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

FROM ubuntu:20.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install --no-install-recommends -y openjdk-17-jre-headless wget ca-certificates;


RUN wget -O- https://archive.apache.org/dist/activemq/5.17.3/apache-activemq-5.17.3-bin.tar.gz \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-activemq-5.17.3 /opt/activemq; \
    cd /opt/activemq; \
    rm --recursive docs examples webapps-demo;


EXPOSE 8161 61616

COPY activemq-*.xml /opt/activemq/conf/

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh

ENV ACTIVEMQ_OPTS -Djetty.host=0.0.0.0

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF ActiveMQ" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE"
