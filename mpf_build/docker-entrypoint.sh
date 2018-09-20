#!/usr/bin/bash

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

# Usage:
# mkdir $(pwd)"/mpf_build/.m2
# docker run mpf_build \
#  --mount type=bind,source="$(pwd)"/mpf_build/.m2,target=/root/.m2

set -Eeo pipefail

export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

# Add Maven dependencies (CMU Sphinx, etc.):
tar xzf /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz \
    -C /root/.m2/repository/

cd /home/mpf/openmpf-projects/openmpf
mvn clean install -DskipTests -Dmaven.test.skip=true -DskipITs \
    -Dmaven.tomcat.skip=true  \
    -Dcomponents.build.package.json=/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/openmpf-open-source-package.json \
    -Dstartup.auto.registration.skip=false \
    -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
    -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
    -DgitShortId=`cd .. && git rev-parse --short HEAD` \
    -DjenkinsBuildNumber=1

# TODO: Copy artifacts to host
# cd /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager
# cp target/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war
# cd ../..
# cp trunk/install/libexec/node-manager /etc/init.d/

# node_manager
#COPY --from=mpf_build /apps/bin/jdk-*-linux-x64.rpm /apps/bin/
#COPY --from=mpf_build /apps/install/bin/ffmpeg /apps/install/bin/ffprobe /apps/install/bin/ffserver $MPF_HOME/bin/
#COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
#COPY --from=mpf_build /etc/profile.d/mpf.sh /etc/profile.d/mpf.sh
#COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ $MPF_HOME/
#COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages $MPF_HOME/share/components

# workflow_manager specific
#COPY --from=mpf_build /opt/apache-tomcat/ /opt/apache-tomcat/
#COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/ansible/ /home/mpf/openmpf-projects/openmpf/trunk/ansible/
