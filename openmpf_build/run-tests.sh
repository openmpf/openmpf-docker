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

BUILD_ARTIFACTS_PATH=/mnt/build_artifacts


# Make sure MPF_HOME matches what it's set to in the node-manager container.
ln -s /home/mpf/openmpf-projects/openmpf/trunk/install /opt/mpf
MPF_HOME=/opt/mpf

mkdir -p $MPF_HOME/share; chown -R mpf:mpf $MPF_HOME/share


# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*workflow_manager*.list

# NOTE: $HOSTNAME is not known until runtime.
echo "export JGROUPS_TCP_ADDRESS=${HOSTNAME}" >> /etc/profile.d/mpf.sh

################################################################################
# Configure Properties                                                         #
################################################################################

mkdir -p "$MPF_HOME/share/config"

echo "node.auto.config.enabled=true" >> "$MPF_HOME/share/config/mpf-custom.properties"
echo "node.auto.unconfig.enabled=true" >> "$MPF_HOME/share/config/mpf-custom.properties"

################################################################################
# Run Integration Tests                                                        #
################################################################################

# Wait for mySQL service.
set +o xtrace
echo "Waiting for MySQL to become available ..."
until mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" -e "quit" >> /dev/null 2>&1; do
  echo "MySQL is unavailable. Sleeping."
  sleep 5
done
echo "MySQL is up"

# Wait for Redis service.
echo "Waiting for Redis to become available ..."
# From https://stackoverflow.com/a/39214806
until [ +PONG = "$( (exec 8<>/dev/tcp/redis/6379 && echo -e 'PING\r\n' >&8 && head -c 5 <&8; exec 8>&-) 2>/dev/null )" ]; do
  echo "Redis is unavailable. Sleeping."
  sleep 5
done
echo "Redis is up"

# Wait for ActiveMQ service.
echo "Waiting for ActiveMQ to become available ..."
until curl -I "$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1; do
  echo "ActiveMQ is unavailable. Sleeping."
  sleep 5
done
echo "ActiveMQ is up"

set -o xtrace

# TODO: Move to openmpf_build Dockerfile
export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

cd /home/mpf/openmpf-projects/openmpf

# Move test sample data into a location that's accessible by all of the nodes.
systemTestSamplesPath="trunk/mpf-system-tests/src/test/resources/samples"
mv  "$systemTestSamplesPath" "$MPF_HOME/share/"
ln -s "$MPF_HOME/share/samples" "$systemTestSamplesPath"

wfmTestSamplesPath="trunk/workflow-manager/src/test/resources/samples"
mv "$wfmTestSamplesPath"/* "$MPF_HOME/share/samples"
rmdir "$wfmTestSamplesPath"
ln -s "$MPF_HOME/share/samples" "$wfmTestSamplesPath"

# Components have already been built in the mpf_post_build image. Only build example components here.
# Only run integration tests. Unit tests can be run in the openmpf_build container.
# $MVN_OPTIONS will override other options that appear earlier in the following command.
# TODO: -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports,
# TODO: -Dtest=TestSystemNightly
# TODO: -Dtest=TestSystemStress
# TODO: Build example components here.
mvn verify \
  -Dspring.profiles.active=jenkins -Pjenkins \
  -Dtest=TestSystemOnDiff \
  -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports \
  -DfailIfNoTests=false \
  -Dtransport.guarantee="NONE" -Dweb.rest.protocol="http" \
  -Dcomponents.build.components=\
    openmpf-cpp-component-sdk/detection/examples:\
    openmpf-java-component-sdk/detection/examples:\
    openmpf-python-component-sdk/detection/examples/PythonTestComponent:\
    openmpf-python-component-sdk/detection/examples/PythonOcvComponent \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
  -DgitShortId=`cd .. && git rev-parse --short HEAD` \
  -DjenkinsBuildNumber=1 \
  $MVN_OPTIONS
mavenRetVal=$?

# Copy Maven test reports to host
cd /home/mpf/openmpf-projects
mkdir -p "$BUILD_ARTIFACTS_PATH/surefire-reports"
find . -path  \*\surefire-reports\*.xml -exec cp {} "$BUILD_ARTIFACTS_PATH/surefire-reports" \;

mkdir -p "$BUILD_ARTIFACTS_PATH/failsafe-reports"
find . -path  \*\failsafe-reports\*.xml -exec cp {} "$BUILD_ARTIFACTS_PATH/failsafe-reports" \;

set +o xtrace
# Exit now if any tests failed
if [ $mavenRetVal -ne 0 ]; then
    echo 'DETECTED INTEGRATION TEST FAILURE(S)'
    exit 1
fi
echo 'DETECTED INTEGRATION TESTS PASSED'
exit 0