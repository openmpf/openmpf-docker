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


# Separate stage so we don't have to re-download things when openmpf_build changes
FROM ubuntu:20.04 as download_dependencies

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp \
    apt-get update; \
    apt-get install --no-install-recommends -y openjdk-17-jre-headless wget ca-certificates patch;


RUN mkdir /scripts; \
    cd /scripts; \
    wget https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh; \
    chmod +x wait-for-it.sh;

RUN wget -O- 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;

RUN mvn dependency:get -Dartifact=org.apache.maven.plugins:maven-surefire-plugin:2.22.1; \
    mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit4:2.22.1; \
    mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit47:2.22.1; \
    mvn dependency:get -Dartifact=org.springframework.boot:spring-boot-maven-plugin:2.7.4



FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} as integration_tests

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

# Copy Maven repository out of cache mount so that the Maven dependencies can be used when running the
# integration tests. This is necessary because the cache mount is only available at build time and the
# integration tests run at run time.
RUN --mount=type=cache,id=mvn_cache,target=/mnt/mvn,sharing=private \
    mkdir --parents /root/.m2/repository; \
    cp --recursive /mnt/mvn/* /root/.m2/repository;

RUN cp --recursive /build-artifacts/mvn/mpf /root/.m2/repository/org/mitre

COPY --from=download_dependencies /root/.m2/repository /root/.m2/repository

COPY --from=download_dependencies /scripts/wait-for-it.sh /scripts/wait-for-it.sh

ENV THIS_MPF_NODE=workflow-manager

ENV MPF_HOME /opt/mpf

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install "$MPF_HOME"

ENV REDIS_HOST=redis

ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV PATH=$PATH:$MPF_HOME/bin
ENV WFM_BASE_URL=http://localhost:8181
# Default for JDBC configuration. Can be overridden at runtime.
ENV JDBC_URL=jdbc:postgresql://db:5432/mpf
ENV PYTHONUNBUFFERED 1

COPY descriptor-receiver.py /scripts/descriptor-receiver.py
COPY check-test-reports.py /scripts/check-test-reports.py
COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.name="OpenMPF Integration Tests"
