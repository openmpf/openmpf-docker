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


# Separate stage so we don't have to re-download things when openmpf_build changes
FROM centos:7 as download_dependencies

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

RUN yum-config-manager --setopt=skip_missing_names_on_install=False --save; \
    yum install -y java-11-openjdk; \
    yum clean all; \
    rm -rf /var/cache/yum/*;

ENV JAVA_HOME /etc/alternatives/jre

RUN curl --location 'http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.41/bin/apache-tomcat-8.5.41.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat; \
    rm --recursive /opt/apache-tomcat/webapps/examples; \
    rm --recursive /opt/apache-tomcat/webapps/docs; \
    rm --recursive /opt/apache-tomcat/webapps/ROOT; \
    # Configure Tomcat cache size:
    # https://stackoverflow.com/questions/26893297/tomcat-8-throwing-org-apache-catalina-webresources-cache-getresource-unable-to
    sed --in-place '24s/.*/    <WatchedResource>$\{catalina\.ba\se\}\/conf\/web.xml<\/WatchedResource>\n    <Resources cachingAllowed="true" cacheMaxSize="100000" \/>/' \
            /opt/apache-tomcat/conf/context.xml;

RUN mkdir /scripts; \
    curl --location https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
        > /scripts/wait-for-it.sh; \
    chmod +x /scripts/wait-for-it.sh;

RUN curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;

RUN mvn dependency:get -Dartifact=org.apache.maven.plugins:maven-surefire-plugin:2.22.1; \
    mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit4:2.22.1; \
    mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit47:2.22.1; \
    mvn dependency:get -Dartifact=org.codehaus.cargo:cargo-maven2-plugin:1.4.8; \
    mvn dependency:get -Dartifact=org.codehaus.cargo:cargo-core-container-tomcat:1.4.8;



FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} as integration_tests

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

# Copy Maven repository out of cache mount so that the Maven dependencies can be used when running the
# integration tests. This is necessary because the cache mount is only available at build time and the
# integration tests run at run time.
RUN --mount=type=cache,id=mvn_cache,target=/mnt/mvn,sharing=private \
    mkdir --parents /root/.m2/repository; \
    cp --recursive /mnt/mvn/* /root/.m2/repository;

RUN cp --recursive /build-artifacts/mvn/mpf /root/.m2/repository/org/mitre

COPY --from=download_dependencies /opt/apache-tomcat-8.5.41 /opt/apache-tomcat-8.5.41
RUN ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat

COPY --from=download_dependencies /root/.m2/repository /root/.m2/repository

COPY --from=download_dependencies /scripts/wait-for-it.sh /scripts/wait-for-it.sh

ENV THIS_MPF_NODE=workflow-manager

ENV MPF_HOME /opt/mpf

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install "$MPF_HOME"

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV REDIS_HOST=redis

ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV PATH=$PATH:$MPF_HOME/bin
ENV CATALINA_OPTS "-Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
ENV TOMCAT_BASE_URL=http://localhost:8181
# Default for JDBC configuration. Can be overridden at runtime.
ENV JDBC_URL=jdbc:postgresql://db:5432/mpf
ENV PYTHONUNBUFFERED 1

COPY descriptor-receiver.py /scripts/descriptor-receiver.py
COPY check-test-reports.py /scripts/check-test-reports.py
COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.name="OpenMPF Integration Tests"
