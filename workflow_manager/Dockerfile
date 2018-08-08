#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2018 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2018 The MITRE Corporation                                      #
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

FROM mpf_build

# TODO: A new container can be made to include only the WAR file and a JRE.
FROM centos:7.4.1708

################################################################################
# Initial Setup                                                                #
################################################################################

ENV MPF_HOME=/opt/mpf
VOLUME $MPF_HOME/share

################################################################################
# Install Oracle JDK                                                           #
################################################################################

COPY --from=mpf_build /apps/bin/jdk-*-linux-x64.rpm /apps/bin/

# Install Oracle JDK:
RUN yum -y localinstall --nogpgcheck /apps/bin/jdk-*-linux-x64.rpm; \
    alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_144/jre/bin/java 20000; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --install /usr/bin/javac javac /usr/java/jdk1.8.0_144/bin/javac 20000; \
    alternatives --install /usr/bin/javaws javaws /usr/java/jdk1.8.0_144/jre/bin/javaws 20000; \
    alternatives --set java /usr/java/jdk1.8.0_144/jre/bin/java; \
    alternatives --set javaws /usr/java/jdk1.8.0_144/jre/bin/javaws; \
    alternatives --set javac /usr/java/jdk1.8.0_144/bin/javac; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar;

################################################################################
# Install yum Dependencies                                                     #
################################################################################

RUN yum update -y; yum install -y epel-release git asciidoc rpm-build \
    python2-devel PyYAML python-httplib2 python-jinja2 libtomcrypt \
    python-paramiko python-six sshpass which; yum clean all

# TODO: For some reason this needs to be a separate step. I think it's because the
#   mirror is choses for the other yum install does not have python-keyczar.
RUN yum install -y python-keyczar; yum clean all

################################################################################
# Install Ansible                                                              #
################################################################################

# Ansible:
RUN mkdir -p /apps/source/ansible_sources; cd /apps/source/ansible_sources; \
    git clone https://github.com/ansible/ansible.git --recursive; \
    cd ansible; git checkout e71cce777685f96223856d5e6cf506a9ea2ef3ff; \
    git submodule update --init --recursive; \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/core; \
    git checkout 36f512abc1a75b01ae7207c74cdfbcb54a84be54; \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/extras; \
    git checkout 32338612b38d1ddfd0d42b1245c597010da02970; \
    cd /apps/source/ansible_sources/ansible; make rpm; \
    cd /apps/source/ansible_sources/ansible; rpm -Uvh ./rpm-build/ansible-*.noarch.rpm

################################################################################
# Copy Files                                                                   #
################################################################################

# NOTE: This will change the most often so it should  be as far down in the Dockerfile as possible.

# TODO: The more steps that can be kept the same (and in the same order) as the
#   node_manager Dockerfile, the more docker can share the build steps
#   between the containers. All shared steps (installing java, copying files
#   from mpf_build) should be moved to the top of both Dockerfiles.

# TODO: Trim the fat from the copies.

# Copy files from the build image:
COPY --from=mpf_build /apps/install/ /apps/install/
COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
COPY --from=mpf_build /opt/apache-tomcat/ /opt/apache-tomcat/
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/ansible/ \
    /home/mpf/openmpf-projects/openmpf/trunk/ansible/

# TODO: Copy files from a shared "artifacts" build context:
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ \
    $MPF_HOME
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages \
    $MPF_HOME/share/components

# Extract tar.gz (using tar xzf) components to $MPF_HOME/plugins:
RUN mkdir $MPF_HOME/plugins; cd $MPF_HOME/plugins; \
    for file in $MPF_HOME/share/components/*.tar.gz; do tar xzf "$file"; done

# Link FFmpeg:
RUN ln -s /apps/install/bin/ffmpeg /usr/bin/ffmpeg

RUN ldconfig

################################################################################
# Configure Environment Variables                                              #
################################################################################

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI=failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV JGROUPS_TCP_ADDRESS=workflow_manager
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV THIS_MPF_NODE=workflow_manager
ENV CORE_MPF_NODES=node_manager
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV CATALINA_OPTS="-server -Xms256m -XX:PermSize=512m -XX:MaxPermSize=512m -Duser.country=US -Djava.library.path=$MPF_HOME/lib -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"

RUN echo '[mpf-master]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts; \
    echo '' >> /etc/ansible/hosts; echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo "node_manager" >> /etc/ansible/hosts

EXPOSE 8080
RUN echo "rm -f $MPF_HOME/share/nodes/MPF_Channel/*workflow_manager*.list && /opt/apache-tomcat/bin/catalina.sh run" > /home/run.sh
ENTRYPOINT ["sh", "/home/run.sh"]
