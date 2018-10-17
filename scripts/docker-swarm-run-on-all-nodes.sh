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
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

# NOTE: This script prioritizes convenience over security.
# 1. StrictHostKeyChecking is turned off when using SSH.
# 2. sshpass is used to provide a password to the ssh command.

printUsage() {
  echo "Usages:"
  echo "docker-swarm-run-on-all-nodes.sh \"<command>\""
  exit -1
}

if [ ! $# -eq 1 ]; then
  printUsage
fi

command="$1"

read -s -p "Enter SSH user: " sshUser
echo

read -s -p "Enter SSH password: " sshPass
echo
echo

nodeIds=$(docker node ls | sed -n '1!p' | cut -d ' ' -f 1)

while read -r nodeId; do
    nodeAddr=$(docker node inspect "$nodeId" --format '{{ .Status.Addr }}')
    echo "Connecting to $nodeAddr ..."
    
    sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" "$command" < /dev/null
    
    echo
done <<< "$nodeIds"


