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
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

set -o errexit -o pipefail

{
    until curl --silent --fail --head 'http://localhost:5601' > /dev/null ; do
        echo 'Kibana is unavailable. Sleeping.'
        sleep 5
    done

    echo 'Checking if index pattern exists...'
    index_url='http://localhost:5601/api/saved_objects/index-pattern/filebeat-index'
    if curl --silent --fail --head "$index_url"; then
        echo 'Index pattern already exists.'
        exit 0
    fi

    echo 'Creating index pattern...'
    curl --silent --fail "$index_url" \
        --header 'Content-Type: application/json' \
        --header 'kbn-xsrf: true' \
        --data '{"attributes":{"title":"filebeat-*","timeFieldName":"@timestamp"}}'
    echo 'Successfully created index pattern'
} &

set -o xtrace

# Call base image's entry point
exec /usr/local/bin/dumb-init -- "$@"
