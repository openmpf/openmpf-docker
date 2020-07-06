#!/usr/bin/env bash

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

set -Ee

printUsage() {
  echo "Usages:"
  echo "docker-swarm-clean-shared-volume.sh [dir]"
  exit 1
}


subDir="*" # by default, remove everything

if [ $# -eq 1 ]; then
    subDir="$1"
elif [ $# -gt 1 ]; then
    printUsage
fi

dataDir="/data/$subDir"

# Check if the shared volume exists. If not, this returns a non-zero exit code.
docker volume inspect openmpf_shared_data > /dev/null

# Create a helper container that mounts the shared volume. Use an image that we know exists on the user's machine.
# The exact image is not important.
docker run --rm -v openmpf_shared_data:/data --entrypoint sh redis:alpine -c "rm -rf $dataDir"

if [ "$subDir" = "*" ]; then
    echo "Cleared the contents of the shared volume."
else
    echo "Cleared \"$subDir\" from the shared volume."
fi
