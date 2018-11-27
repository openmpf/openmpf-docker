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
    echo "docker-generate-compose-files.sh"
    echo "docker-generate-compose-files.sh -nr [<image-tag>=latest] [<keystore-path>] [<keystore-password>]"
    echo "docker-generate-compose-files.sh <registry> [<repository>=openmpf] [<image-tag>=latest] [<keystore-path>] [<keystore-password>]"
    exit -1
}

# generateWithoutRegistry(1: fileName, 2: imageTag, 3: keystorePath, 4: keystorePassword)
generateWithoutRegistry() {
  cp templates/"$1" "$1"
  sedi "s/<registry_host>:<registry_port>\\/<repository>\\///g" "$1"
  sedi "s/<image_tag>/$2/g" "$1"

  configureHttps "$1" "$3" "$4"
}

# generateWithoutRegistry(1: fileName, 2: registryHost, 3: repository, 4: imageTag, 5: keystorePath, 6: keystorePassword)
generateWithRegistry() {
  cp templates/"$1" "$1"
  sedi "s/<registry_host>:<registry_port>\\/<repository>/$2:$3\\/$4/g" "$1"
  sedi "s/<image_tag>/$5/g" "$1"

  configureHttps "$1" "$5" "$6"
}


# configureHttps(1: fileName, 2: keystorePath, 3: keystorePassword)
configureHttps() {
    if [ "$2" ]; then
        escaped_path="${2//\//\\/}"
        sed -i "s/<keystore_path>/$escaped_path/g" "$1"
        sed -i "s/<keystore_password>/$3/g" "$1"
    else
        sed -i '/<keystore_path>/d' "$1"
        sed -i '/<keystore_password>/d' "$1"
        sed -i '/- "8443:8443"/d' "$1"
        sed -i '/secrets: \[https_keystore\]/d' "$1"
    fi
}

# platform agnostic sed -i
sedi() {
  # sed --version fails on BSD distro of sed. We use the exit code to determine
  #    the required format for sed
  if [ $# -gt 2 ]; then
    sed --version >/dev/null 2>&1 && sed -i "$1" "$2" > "$3" || \
      sed -i "" "$1" "$2" > "$3"
  else
    sed --version >/dev/null 2>&1 && sed -i "$1" "$2" || \
      sed -i "" "$1" "$2"
  fi
}

if [ "$1" = help ] || [ "$1" = --help ]; then
    printUsage
fi

if [ "$1" = -nr ]; then
    if [ $# -gt 4 ]; then
        printUsage
    fi
    if [ $# -eq 3 ]; then
        echo 'If <keystore-path> is provided, <keystore-password> must also be provided.'
        printUsage
    fi
else
    if [ $# -gt 5 ]; then
        printUsage
    fi
    if [ $# -eq 4 ]; then
        echo 'If <keystore-path> is provided, <keystore-password> must also be provided.'
        printUsage
    fi
fi


templateFiles=('docker-compose.yml' 'docker-compose-test.yml' 'swarm-compose.yml')

################################################################################
# Without registry                                                             #
################################################################################

if [ $# -eq 0 ] || [ "$1" = -nr ]; then
    imageTag="${2:-latest}"
    for template in "${templateFiles[@]}"; do
        generateWithoutRegistry "$template" "$imageTag" "$3" "$4"
    done

    exit
fi


################################################################################
# With registry                                                                #
################################################################################

host="$1"
repository="${2:-openmpf}"
imageTag="${3:-latest}"

for template in "${templateFiles[@]}"; do
    generateWithRegistry "$template" "$host" "$repository" "$imageTag" "$4" "$5"
done
