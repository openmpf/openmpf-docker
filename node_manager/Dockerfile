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
    yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes java-11-openjdk ffmpeg; \
    yum clean all; \
    rm -rf /var/cache/yum/*;


ENV MPF_HOME /opt/mpf

COPY --from=openmpf_build /build-artifacts/install $MPF_HOME

COPY --from=openmpf_build /build-artifacts/plugins $MPF_HOME/plugins

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MYSQL_HOST=mysql-database
ENV THIS_MPF_NODE=node-manager
ENV CORE_MPF_NODES=$THIS_MPF_NODE

ENV JGROUPS_TCP_ADDRESS=$THIS_MPF_NODE
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost,$THIS_MPF_NODE
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV MASTER_MPF_NODE=workflow-manager
ENV MAIL=/var/spool/mail/mpf
ENV PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$MPF_HOME/bin:/usr/bin/
ENV HOME=/home/mpf
ENV LOGNAME=mpf
ENV JAVA_HOME=/usr/lib/jvm/jre-11



COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
ENTRYPOINT ["/scripts/docker-entrypoint.sh"]


ARG BUILD_SHAS

LABEL org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Node Manager" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf" \
      org.label-schema.vendor="MITRE"
