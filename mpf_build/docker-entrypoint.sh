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

set -Ee -o pipefail -o xtrace

export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

# Use "docker run --env BUILD_PACKAGE_JSON=openmpf-some-other-package.json" option
BUILD_PACKAGE_JSON=${BUILD_PACKAGE_JSON:=openmpf-open-source-package.json}
BUILD_ARTIFACTS_PATH=/home/mpf/build_artifacts

# Start with a clean slate
rm -rf $BUILD_ARTIFACTS_PATH/*

# Add Maven dependencies (CMU Sphinx, etc.)
tar xzf /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz \
    -C /root/.m2/repository/

# Perform build
cd /home/mpf/openmpf-projects/openmpf
mvn clean install -DskipTests -Dmaven.test.skip=true -DskipITs \
    -Dmaven.tomcat.skip=true  \
    -Dcomponents.build.package.json=/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/$BUILD_PACKAGE_JSON \
    -Dstartup.auto.registration.skip=false \
    -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
    -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
    -DgitShortId=`cd .. && git rev-parse --short HEAD` \
    -DjenkinsBuildNumber=1

# Copy build artifacts to host
cd /home/mpf/openmpf-projects/openmpf/trunk
cp workflow-manager/target/workflow-manager.war $BUILD_ARTIFACTS_PATH

# Exclude the share directory since it can't be extracted to the share volume.
# Docker cannot extract tars, or mv files to, volumes when the container is being created.
tar -czf $BUILD_ARTIFACTS_PATH/install.tar -C install --exclude="share" .
tar -czf $BUILD_ARTIFACTS_PATH/ansible.tar ansible

cp -R ../mpf-component-build/plugin-packages $BUILD_ARTIFACTS_PATH
