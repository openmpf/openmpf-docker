#!/usr/bin/bash

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

set -Ee -o pipefail -o xtrace

################################################################################
# Initial Setup                                                                #
################################################################################

export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH="$PATH":/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

SOURCE_CODE_PATH=/mnt/openmpf-projects
BUILD_ARTIFACTS_PATH=/mnt/build_artifacts

# Use "docker run --env BUILD_PACKAGE_JSON=openmpf-some-other-package.json" option
BUILD_PACKAGE_JSON=${BUILD_PACKAGE_JSON:=openmpf-open-source-package.json}

# Start with a clean slate
rm -rf "$BUILD_ARTIFACTS_PATH"/*

################################################################################
# Copy the OpenMPF Repository                                                  #
################################################################################

cp -R "$SOURCE_CODE_PATH" /home/mpf

# Make sure the source code line endings are correct if copying the source from a Windows host.
cd /home/mpf/openmpf-projects && find . -type f -exec dos2unix -q {} \;

# TODO: Update the command line tools to remove Redis, mySQL, and ActiveMQ startup
# Install OpenMPF command line tools:
pip install /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts

################################################################################
# Prepare to Build OpenMPF                                                     #
################################################################################

# Copy the development properties file to run the OpenMPF on the OpenMPF Build Machine:
cp /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/properties/mpf-private-example.properties \
    /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/properties/mpf-private.properties

# TODO: See if this can be converted to use ARG variable, this strategy is
#    very brittle because it's based on line number:
sed -i '37s/.*/              p:hostName="redis"/' \
    /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/applicationContext-redis.xml

# Add Maven dependencies (CMU Sphinx, etc.)
mkdir -p /root/.m2/repository
tar xzf /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz \
  -C /root/.m2/repository/

################################################################################
# Custom Steps                                                                 #
################################################################################

# If this is a custom build, run the custom entrypoint steps.
if [ -f /home/mpf/docker-custom-entrypoint.sh ]; then
  /home/mpf/docker-custom-entrypoint.sh
fi

################################################################################
# Build OpenMPF                                                                #
################################################################################

parallelism=$(($(nproc) / 2))
(( parallelism < 2 )) && parallelism=2

# Perform build. Exit script on failure.
cd /home/mpf/openmpf-projects/openmpf
mvn clean install \
  -DskipTests -Dmaven.test.skip=true -DskipITs \
  -Dmaven.tomcat.skip=true \
  -Dcomponents.build.package.json="/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/$BUILD_PACKAGE_JSON" \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -Dcomponents.build.parallel.builds="$parallelism" \
  -Dcomponents.build.make.jobs="$parallelism" \
  -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
  -DgitShortId=`cd .. && git rev-parse --short HEAD` \
  -DjenkinsBuildNumber=1

################################################################################
# Copy Artifacts to Host                                                       #
################################################################################

cd /home/mpf/openmpf-projects/openmpf/trunk
cp workflow-manager/target/workflow-manager.war "$BUILD_ARTIFACTS_PATH"

# Exclude the share directory since it can't be extracted to the share volume.
# Docker cannot extract tars, or mv files to, volumes when the container is being created.
tar -czf "$BUILD_ARTIFACTS_PATH/install.tar" -C install --exclude="share" .
tar -czf "$BUILD_ARTIFACTS_PATH/ansible.tar" ansible

cp -R ../mpf-component-build/plugin-packages "$BUILD_ARTIFACTS_PATH"
