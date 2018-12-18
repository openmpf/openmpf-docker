#!/usr/bin/env bash

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

set -Ee

finally() {
    docker rm -f openmpf_helper > /dev/null
}

# Check if the shared volume exists. If not, this returns a non-zero exit code.
docker volume inspect openmpf_shared_data > /dev/null

# Ensure that we clean up the helper container that we'll be creating next.
trap finally EXIT

# Create a helper container that mounts the shared volume. Use an image that we know exists.
# The exact image is not important.
docker run -d --rm --entrypoint bash -v openmpf_shared_data:/data --name openmpf_helper redis -c "sleep infinity" > /dev/null

docker exec openmpf_helper bash -c "rm -rf /data/*"

echo "Cleared the contents of the shared volume."