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
# distributed under the License is distributed don an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

set -Ee -o pipefail -o xtrace

# Setup
# NOTE: $HOSTNAME is not known until runtime.
echo "export THIS_MPF_NODE=${THIS_MPF_NODE}_id_${HOSTNAME}" >> /etc/profile.d/mpf.sh
echo "export JGROUPS_TCP_ADDRESS=${HOSTNAME}" >> /etc/profile.d/mpf.sh

# Run node-manager (as root user)
$MPF_HOME/libexec/node-manager start

touch ${MPF_LOG_PATH}/${THIS_MPF_NODE}_id_${HOSTNAME}/log/node-manager.log
tail -f ${MPF_LOG_PATH}/${THIS_MPF_NODE}_id_${HOSTNAME}/log/node-manager.log
