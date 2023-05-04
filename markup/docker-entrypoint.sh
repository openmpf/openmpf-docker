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

# NOTE: $HOSTNAME is not known until runtime.
export THIS_MPF_NODE="${THIS_MPF_NODE}_id_${HOSTNAME}"

if [ ! "$ACTIVE_MQ_BROKER_URI" ]; then
    export ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
fi

# --spider makes wget use a HEAD request
# wget exits with code 6 when there is an authentication error. This is expected because the
# ActiveMQ status page requires authentication. We are just using the request to verify ActiveMQ
# is running so there is no need to authenticate.
echo 'Waiting for ActiveMQ to become available ...'
until wget --spider --tries 1 "http://$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1 || [ $? -eq 6 ]; do
    echo 'ActiveMQ is unavailable. Sleeping.'
    sleep 5
done
echo 'ActiveMQ is up'

set -o xtrace

exec java -jar mpf-markup-*.jar "$ACTIVE_MQ_BROKER_URI"
