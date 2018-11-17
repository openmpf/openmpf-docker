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

set -Ee -o pipefail

printUsage() {
  echo "Usages:"
  echo "docker-generate-compose-files.sh [<image-tag>]"
  echo "docker-generate-compose-files.sh <registry-host> <registry-port> [<repository>] [<image-tag>]"
  exit -1
}

# generateWithoutRegistry(fileName, imageTag)
generateWithoutRegistry() {
  sed "s/<registry_host>:<registry_port>\\/<repository>\\///g" templates/"$1" > "$1"
  sed -i "s/<image_tag>/$2/g" "$1"
}

# generateWithoutRegistry(fileName, registryHost, registryPort, repository, imageTag)
generateWithRegistry() {
  sed "s/<registry_host>:<registry_port>\\/<repository>/$2:$3\\/$4/g" templates/"$1" > "$1"
  sed -i "s/<image_tag>/$5/g" "$1"
}

if [ $# -gt 4 ]; then
  printUsage
fi

################################################################################
# Without registry                                                             #
################################################################################

if [ $# -lt 2 ]; then
  if [ $# -eq 0 ]; then
    imageTag="latest"
  else
    imageTag="$1"
  fi
  generateWithoutRegistry "docker-compose.yml" "$imageTag"
  generateWithoutRegistry "docker-compose-test.yml" "$imageTag"
  generateWithoutRegistry "swarm-compose.yml" "$imageTag"
  exit
fi

################################################################################
# With registry                                                                #
################################################################################

host="$1"
port="$2"

if [ $# -lt 3 ]; then
  repository="openmpf"
else
  repository="$3"
fi

if [ $# -lt 4 ]; then
  imageTag="latest"
else
  imageTag="$4"
fi

generateWithRegistry "docker-compose.yml" "$host" "$port" "$repository" "$imageTag"
generateWithRegistry "docker-compose-test.yml" "$host" "$port" "$repository" "$imageTag"
generateWithRegistry "swarm-compose.yml" "$host" "$port" "$repository" "$imageTag"
