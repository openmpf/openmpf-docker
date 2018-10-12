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

BUILD_PACKAGE_JSON=${BUILD_PACKAGE_JSON:=openmpf-open-source-package.json}

# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*workflow_manager*.list

# Configure
echo 'node.auto.config.enabled=true' >> $MPF_HOME/config/mpf-custom.properties
echo 'node.auto.unconfig.enabled=true' >> $MPF_HOME/config/mpf-custom.properties

# echo "THIS IS A WFM TEST!"

# TODO: Move to mpf_build Dockerfile
export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
export CXXFLAGS=-isystem\ /apps/install/include
export PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin

cd /home/mpf/openmpf-projects/openmpf
# TODO: -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports, -DskipITs
mvn verify \
  -Dspring.profiles.active=jenkins -Pjenkins \
  -DfailIfNoTests=false \
  -Dit.test=ITComponentRegistration,ITWebStreamingReports \
  -Dtransport.guarantee="NONE" -Dweb.rest.protocol="http" \
  -Dcomponents.build.package.json=/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/$BUILD_PACKAGE_JSON \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -DgitBranch=`cd .. && git rev-parse --abbrev-ref HEAD` \
  -DgitShortId=`cd .. && git rev-parse --short HEAD` \
  -DjenkinsBuildNumber=1
mavenRetVal=$?

echo 'MAVEN RETVAL: $mavenRetVal' # DEBUG
exit $mavenRetVal # DEBUG