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

# NOTE: This script prioritizes convenience over security.
# 1. StrictHostKeyChecking is turned off when using SSH.
# 2. Optionally, sshpass is used to provide a password to the ssh command.

printUsage() {
  echo "Usages:"
  echo "docker-swarm-run-on-all-nodes.sh [--ask-pass] \"<command>\""
  exit 1
}

if [ $# -eq 1 ]; then
  askPass=0
  command="$1"
elif [ $# -eq 2 ]; then
  if [ "$1" != "--ask-pass" ]; then
    printUsage
  fi
  askPass=1
  command="$2"
else
  printUsage
fi

if [ $askPass = 1 ]; then
  read -s -p "Enter SSH user: " sshUser
  echo

  read -s -p "Enter SSH password: " sshPass
  echo
  echo
fi

nodeIds=$(docker node ls | sed -n '1!p' | cut -d ' ' -f 1)

while read -r nodeId; do
  nodeAddr=$(docker node inspect "$nodeId" --format '{{ .Status.Addr }}')
  echo "Connecting to $nodeAddr ..."

  if [ $askPass = 1  ]; then
    sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" "$command" < /dev/null
  else
    ssh -oStrictHostKeyChecking=no "$nodeAddr" "$command" < /dev/null
  fi

  echo
done <<< "$nodeIds"
