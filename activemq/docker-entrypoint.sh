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

set -Ee -o pipefail -o xtrace

################################################################################
# Custom Steps                                                                 #
################################################################################

cd /opt/activemq/conf
# Put the appropriate activemq.xml file into place
cp /opt/activemq/conf/activemq-$ACTIVE_MQ_PROFILE.xml activemq.xml

# Put the appropriate env file in place
cd /opt/activemq/bin
cp env.$ACTIVE_MQ_PROFILE env

# Start streaming logs to logstash, if enabled
if [ "$ENABLE_FILEBEAT" = true ]
then
  /etc/init.d/filebeat start
fi

# This script from the webcenter/activemq image runs activemq under supervisord.
/app/run.sh

