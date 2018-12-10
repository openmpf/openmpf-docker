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

################################################################################
# Initial Setup                                                                #
################################################################################

BUILD_ARTIFACTS_PATH=/mnt/build_artifacts

# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*workflow_manager*.list

# NOTE: $HOSTNAME is not known until runtime.
echo "export JGROUPS_TCP_ADDRESS=${HOSTNAME}" >> /etc/profile.d/mpf.sh

################################################################################
# Run Integration Tests                                                        #
################################################################################

# Wait for mySQL service.
set +o xtrace
echo "Waiting for MySQL to become available ..."
until mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" -e "quit" >> /dev/null 2>&1; do
  echo "MySQL is unavailable. Sleeping."
  sleep 1
done
echo "MySQL is up"
set -o xtrace

# TODO: Move to openmpf_build Dockerfile
export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

cd /home/mpf/openmpf-projects/openmpf
# Leave "components.build.package.json" blank. The components should have
# already been built in the mpf_post_build image.
# TODO: -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports, -DskipITs
mvn verify \
  -Dspring.profiles.active=jenkins -Pjenkins \
  -DfailIfNoTests=false \
  -Dit.test=ITComponentRegistration,ITWebStreamingReports \
  -Dtransport.guarantee="NONE" -Dweb.rest.protocol="http" \
  -Dcomponents.build.package.json= \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
  -DgitShortId=`cd .. && git rev-parse --short HEAD` \
  -DjenkinsBuildNumber=1
mavenRetVal=$?

# Copy Maven test reports to host
cd /home/mpf/openmpf-projects
mkdir -p $BUILD_ARTIFACTS_PATH/surefire-reports
find . -path  \*\surefire-reports\*.xml -exec cp {} $BUILD_ARTIFACTS_PATH/surefire-reports \;

mkdir -p $BUILD_ARTIFACTS_PATH/failsafe-reports
find . -path  \*\failsafe-reports\*.xml -exec cp {} $BUILD_ARTIFACTS_PATH/failsafe-reports \;

set +o xtrace
# Exit now if any tests failed
if [ $mavenRetVal -ne 0 ]; then
    echo 'DETECTED INTEGRATION TEST FAILURE(S)'
    exit 1
fi
set -o xtrace
