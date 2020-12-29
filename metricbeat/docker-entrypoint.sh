#!/bin/bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
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

until curl --silent --fail --head 'http://kibana:5601' > /dev/null ; do
    echo 'Kibana is unavailable. Sleeping.'
    sleep 5
done

set -o xtrace

echo 'Checking if index pattern exists...'
index_url='http://kibana:5601/api/saved_objects/index-pattern/metricbeat-index'
if curl --silent --fail --head "$index_url"; then
    echo 'Index pattern already exists.'
else
    echo 'Creating index pattern and visualizations...'
    metricbeat setup -E setup.kibana.host=kibana:5601 -E output.elasticsearch.hosts=elasticsearch:9200 # DEBUG
    # metricbeat setup
    echo 'Successfully created index pattern and visualizations'
fi

# Call base image's entry point
exec /usr/local/bin/docker-entrypoint "$@"
