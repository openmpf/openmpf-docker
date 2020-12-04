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


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

RUN yum update --assumeyes; \
    yum install --assumeyes java-11-openjdk-headless; \
    yum clean all; \
    rm -rf /var/cache/yum/*;

ENV JAVA_HOME /etc/alternatives/jre


RUN curl --location https://archive.apache.org/dist/activemq/5.16.0/apache-activemq-5.16.0-bin.tar.gz \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-activemq-5.16.0 /opt/activemq; \
    # Originally line 119 was <property name="host" value="127.0.0.1"/>
    # which prevented access to Web UI outside of container.
    sed -i '119s/.*/        <property name="host" value="0.0.0.0"\/>/' \
            /opt/activemq/conf/jetty.xml; \
    cd /opt/activemq; \
    rm --recursive docs examples webapps-demo;


EXPOSE 8161 61616

COPY activemq-*.xml /opt/activemq/conf/

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF ActiveMQ" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE"
