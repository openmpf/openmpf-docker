#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2023 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2023 The MITRE Corporation                                      #
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

set -o errexit -o pipefail

source /scripts/set-file-env-vars.sh
/scripts/install-ca-certs.sh

# NOTE: $HOSTNAME is not known until runtime.
export THIS_MPF_NODE="${THIS_MPF_NODE}_id_${HOSTNAME}"

if [ ! "$ACTIVE_MQ_BROKER_URI" ]; then
    # Set reconnect attempts so that about 5 minutes will be spent attempting to reconnect.
    export ACTIVE_MQ_BROKER_URI="failover:(tcp://$ACTIVE_MQ_HOST:61616)?maxReconnectAttempts=13&startupMaxReconnectAttempts=21"
fi

set -o xtrace

exec java -jar mpf-markup-*.jar "$ACTIVE_MQ_BROKER_URI"
