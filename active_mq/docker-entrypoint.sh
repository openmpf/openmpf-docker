#!/bin/bash

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
# distributed under the License is distributed don an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

set +x -Ee -o pipefail -o xtrace

################################################################################
# Custom Steps                                                                 #
################################################################################

# If this is a custom build, run the custom entrypoint steps.
#if [ -f /home/mpf/docker-custom-entrypoint.sh ]; then
#  /home/mpf/docker-custom-entrypoint.sh
#fi

echo "Change directory to /opt/activemq/conf"
cd /opt/activemq/conf
echo "ACTIVEMQ_PROFILE =" $ACTIVEMQ_PROFILE
# Put the appropriate activemq.xml file into place
echo "Put activemq-$ACTIVEMQ_PROFILE.xml file into place"
cp /opt/activemq/conf/activemq-$ACTIVEMQ_PROFILE.xml activemq.xml

# Put the appropriate env file in place
echo "Change directory to /opt/activemq/bin"
cd /opt/activemq/bin
echo "Put  env.$ACTIVEMQ_PROFILE file into place"
cp env.$ACTIVEMQ_PROFILE env

echo "Run /app/run.sh"

/app/run.sh

