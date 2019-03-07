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

ARG POST_BUILD_IMAGE_NAME=mpf_post_build:latest
FROM $POST_BUILD_IMAGE_NAME as mpf_post_build

################################################################################
# Initial Setup                                                                #
################################################################################

RUN ln -s /home/mpf/openmpf-projects/openmpf/trunk/install /opt/mpf

# Make sure MPF_HOME matches what it's set to in the node-manager container.
ENV MPF_HOME=/opt/mpf

RUN mkdir -p $MPF_HOME/share; chown -R mpf:mpf $MPF_HOME/share

################################################################################
# Install yum Dependencies                                                     #
################################################################################

RUN yum install -y git asciidoc rpm-build \
    python2-devel PyYAML python-httplib2 python-jinja2 libtomcrypt \
    python-paramiko python-six sshpass which mysql dos2unix && \
    yum clean all && rm -rf /var/cache/yum/*

# TODO: For some reason this needs to be a separate step. I think it's because the
#   mirror it choses for the other yum install does not have python-keyczar.
#   This happens even if python-keyczar is the first thing in the list.
RUN yum install -y python-keyczar && yum clean all

################################################################################
# Install Ansible                                                              #
################################################################################

# TODO: Build the Ansible RPM on openmpf_build; install on workflow_manager

# Ansible:
RUN mkdir -p /apps/source/ansible_sources && cd /apps/source/ansible_sources && \
    git clone https://github.com/ansible/ansible.git --recursive && \
    cd ansible && git checkout e71cce777685f96223856d5e6cf506a9ea2ef3ff && \
    git submodule update --init --recursive && \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/core && \
    git checkout 36f512abc1a75b01ae7207c74cdfbcb54a84be54 && \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/extras && \
    git checkout 32338612b38d1ddfd0d42b1245c597010da02970 && \
    cd /apps/source/ansible_sources/ansible && make rpm && \
    cd /apps/source/ansible_sources/ansible && \
    rpm -Uvh ./rpm-build/ansible-*.noarch.rpm

################################################################################
# Configure Environment Variables                                              #
################################################################################

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI=failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV THIS_MPF_NODE=workflow_manager
# JGROUPS_TCP_ADDRESS set in docker-entrypoint-test.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV PATH=$PATH:$MPF_HOME/bin
ENV TOMCAT_BASE_URL=http://$THIS_MPF_NODE:8181

# The workflow manager must be added as an mpf-child so that plugin packages are
# extracted at startup, which is necessary for component auto-registration.
RUN echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts;

################################################################################
# Prepare Entrypoint                                                           #
################################################################################

# If any build steps change the data within the volume after it has been declared, those changes will be discarded.
VOLUME $MPF_HOME/share

EXPOSE 8080

COPY workflow_manager/docker-entrypoint-test.sh /home/mpf
RUN dos2unix -q /home/mpf/docker-entrypoint-test.sh
ENTRYPOINT ["/home/mpf/docker-entrypoint-test.sh"]