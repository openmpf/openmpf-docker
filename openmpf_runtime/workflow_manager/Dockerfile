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

ARG BUILD_IMAGE_NAME=openmpf_build:latest
FROM $BUILD_IMAGE_NAME as openmpf_build

# TODO: A new container can be made to include only the WAR file and a JRE.
FROM centos:7.4.1708

################################################################################
# Initial Setup                                                                #
################################################################################

ENV MPF_HOME=/opt/mpf

# Do this right away so that we fail fast if the user doesn't provide the JDK:
COPY --from=openmpf_build /apps/bin/jdk-*-linux-x64.rpm /apps/bin/

# Create the "mpf" user:
RUN useradd -u 376 -U -d /home/mpf -ms /bin/bash -G wheel -p mpf mpf

RUN mkdir -p $MPF_HOME/share; chown -R mpf:mpf $MPF_HOME/share

# Set up yum repo:
RUN yum install -y epel-release deltarpm && yum clean all
RUN yum update -y && yum clean all

################################################################################
# Install Oracle JDK                                                           #
################################################################################

# Install Oracle JDK:
RUN yum -y localinstall --nogpgcheck /apps/bin/jdk-*-linux-x64.rpm && \
    alternatives --install /usr/bin/java java /usr/java/jdk*/jre/bin/java 20000 && \
    alternatives --install /usr/bin/jar jar /usr/java/jdk*/bin/jar 20000 && \
    alternatives --install /usr/bin/javac javac /usr/java/jdk*/bin/javac 20000 && \
    alternatives --install /usr/bin/javaws javaws /usr/java/jdk*/jre/bin/javaws 20000 && \
    alternatives --set java /usr/java/jdk*/jre/bin/java && \
    alternatives --set javaws /usr/java/jdk*/jre/bin/javaws && \
    alternatives --set javac /usr/java/jdk*/bin/javac && \
    alternatives --set jar /usr/java/jdk*/bin/jar; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk*/bin/jar 20000 && \
    alternatives --set jar /usr/java/jdk*/bin/jar; \
    rm /apps/bin/jdk-*-linux-x64.rpm

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
# Copy Files                                                                   #
################################################################################

# NOTE: This will change the most often so it should  be as far down in the Dockerfile as possible.

# TODO: The more steps that can be kept the same (and in the same order) as the
#   node_manager Dockerfile, the more docker can share the build steps
#   between the containers. All shared steps (installing java, copying files
#   from openmpf_build) should be moved to the top of both Dockerfiles.

# TODO: Trim the fat from the copies.

# Copy files from the build image:
COPY --from=openmpf_build /apps/install/bin/ffmpeg /apps/install/bin/ffprobe \
     /apps/install/bin/ffserver $MPF_HOME/bin/
COPY --from=openmpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
COPY --from=openmpf_build /opt/apache-tomcat/ /opt/apache-tomcat/
COPY --from=openmpf_build /apps/source/ansible_sources/ansible/rpm-build/ansible-*.noarch.rpm .

# Link FFmpeg:
RUN ln -s $MPF_HOME/bin/ffmpeg /usr/bin/ffmpeg && \
    ln -s $MPF_HOME/bin/ffserver /usr/bin/ffserver && \
    ln -s $MPF_HOME/bin/ffprobe /usr/bin/ffprobe

# Install Ansible:
RUN rpm -Uvh ansible-*.noarch.rpm && rm ansible-*.noarch.rpm

COPY build_artifacts/install.tar /home/mpf/
RUN cd /home/mpf && tar -xzf install.tar -C $MPF_HOME && rm install.tar

COPY build_artifacts/plugin-packages $MPF_HOME/share/components

# Extract components:
RUN mkdir $MPF_HOME/plugins && cd $MPF_HOME/plugins && \
    for file in $MPF_HOME/share/components/*.tar.gz; do tar xzf "$file"; done

COPY build_artifacts/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war

# TODO: Choose a better path than /home/mpf/openmpf-projects/openmpf/trunk/ansible on a production container.
# For example: ${env:MPF_HOME}/manage/ansible/roles/child
COPY build_artifacts/ansible.tar /home/mpf/
RUN cd /home/mpf && mkdir -p /home/mpf/openmpf-projects/openmpf/trunk && \
    tar -xzf ansible.tar -C /home/mpf/openmpf-projects/openmpf/trunk && \
    rm ansible.tar

################################################################################
# Configure Environment Variables                                              #
################################################################################

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI=failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV THIS_MPF_NODE=workflow_manager
# JGROUPS_TCP_ADDRESS set in docker-entrypoint.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV PATH=$PATH:$MPF_HOME/bin

# The workflow manager must be added as an mpf-child so that plugin packages are
# extracted at startup, which is necessary for component auto-registration.
RUN echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts;

################################################################################
# Prepare Entrypoint                                                           #
################################################################################

# If any build steps change the data within the volume after it has been declared, those changes will be discarded.
VOLUME $MPF_HOME/share

EXPOSE 8080 8443

COPY workflow_manager/docker-entrypoint.sh /home/mpf
RUN dos2unix -q /home/mpf/docker-entrypoint.sh
ENTRYPOINT ["/home/mpf/docker-entrypoint.sh"]

################################################################################
# Labels                                                                       #
################################################################################

ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_SHAS

# Clear inherited labels from CentOS 7.4.1708 base image.
# TODO: Remove these when we start using a newer CentOS base image.
LABEL build-date= \
      license= \
      name= \
      vendor=

# Set labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Workflow Manager" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor=MITRE \
      org.label-schema.version=$BUILD_VERSION
