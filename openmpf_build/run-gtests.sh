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

################################################################################
# Run Google Tests                                                             #
################################################################################

# TODO: Update A-RunGTests.pl to return a non-zero value
cd /home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts
perl A-RunGTests.pl /home/mpf/openmpf-projects/openmpf 2>&1 | tee A-RunGTests.log

set +o xtrace
gTestsFailed=$(grep -q "GTESTS TESTS FAILED" A-RunGTests.log; echo $?)
set -o xtrace

rm A-RunGTests.log

# Copy GTest reports to host
cd /home/mpf/openmpf-projects/openmpf/mpf-component-build
mkdir -p "$BUILD_ARTIFACTS_PATH/reports/gtest-reports"
find . -name *junit.xml -exec cp {} "$BUILD_ARTIFACTS_PATH/reports/gtest-reports" \;

set +o xtrace
# Exit now if any tests failed
if [ "$gTestsFailed" -eq 0 ]; then
  echo 'DETECTED GOOGLE TEST FAILURE(S)'
  exit 1
fi
echo 'DETECTED GOOGLE TESTS PASSED'
exit 0
