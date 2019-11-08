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

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN yum update --assumeyes; \
    yum install --assumeyes --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes java-11-openjdk ffmpeg tomcat-native python-pip; \
    yum clean all; \
    rm --recursive /var/cache/yum/*; \
    pip install --upgrade pip;


RUN mkdir /scripts; \
    curl --location https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
        > /scripts/wait-for-it.sh; \
    chmod +x /scripts/wait-for-it.sh;


RUN curl --location 'http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.41/bin/apache-tomcat-8.5.41.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat; \
    rm --recursive /opt/apache-tomcat/webapps/*; \
    # Configure Tomcat cache size:
    # https://stackoverflow.com/questions/26893297/tomcat-8-throwing-org-apache-catalina-webresources-cache-getresource-unable-to
    sed --in-place '24s/.*/    <WatchedResource>$\{catalina\.ba\se\}\/conf\/web.xml<\/WatchedResource>\n    <Resources cachingAllowed="true" cacheMaxSize="100000" \/>/' \
        /opt/apache-tomcat/conf/context.xml;


COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts /home/mpf/mpf-scripts
# Make sure mpf-scripts is not globally installed and that the mpf command in not on the $PATH
RUN mkdir --parents /home/mpf/mpf-scripts-install; \
    pip install --no-cache --target /home/mpf/mpf-scripts-install /home/mpf/mpf-scripts

COPY --from=openmpf_build /build-artifacts/workflow-manager.war /opt/apache-tomcat/webapps/

ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/descriptors $MPF_HOME/plugins

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MYSQL_HOST=mysql-database
ENV REDIS_HOST=redis
ENV THIS_MPF_NODE=workflow-manager
# JGROUPS_TCP_ADDRESS set in docker-entrypoint.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=''
ENV LD_LIBRARY_PATH=/usr/lib64:/opt/apache-tomcat/webapps/workflow-manager/WEB-INF/classes
ENV PATH=$PATH:$MPF_HOME/bin
ENV JAVA_HOME=/usr/lib/jvm/jre-11

EXPOSE 8080 8443

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
COPY mpf-users.sh /usr/local/bin/mpf-users

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]


ARG BUILD_SHAS

LABEL org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Workflow Manager" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf" \
      org.label-schema.vendor="MITRE"


