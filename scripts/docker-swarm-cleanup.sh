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
  echo "docker-swarm-cleanup.sh [--ask-pass] <--db-volume|--all-volumes|--no-volumes> [--remove-shared-data]"
  exit 1
}

# parseVolumeType(1: volumeType)
parseVolumeType() {
  if [ "$1" == "--db-volume" ]; then
    removeDbVolume=1
  elif [ "$1" == "--all-volumes" ]; then
    removeAllVolumes=1
  elif [ "$1" != "--no-volumes" ]; then
    printUsage
  fi
}

# parseRemoveSharedData(1: option)
parseRemoveSharedData() {
  if [ "$1" == "--remove-shared-data" ]; then
    removeSharedData=1
  else
    printUsage
  fi
}

# cleanupContainers(1: sshCmd)
cleanupContainers() {
sshCmd="$1"
"${sshCmd[@]}" << "EOF"
containerIds=$(docker ps -a -f name=openmpf_ -q)
if [ ! -z "$containerIds" ]; then
  echo "Removing openmpf containers:"
  docker container rm -f $containerIds;
else \
  echo "No openmpf containers running."
fi
echo
exit
EOF
}

# cleanupDbVolume(1: sshCmd)
cleanupDbVolume() {
sshCmd="$1"
"${sshCmd[@]}" << "EOF"
# Don't remove openmpf_shared_data.
volumeIds=$(docker volume ls -f name=openmpf_db_data -q)
if [ ! -z "$volumeIds" ]; then
  echo "Removing openmpf volumes:"
  docker volume rm -f $volumeIds;
else
  echo "No openmpf_db_data volume found."
fi
echo
exit
EOF
}

# cleanupAllVolumes(1: sshCmd)
cleanupAllVolumes() {
sshCmd="$1"
"${sshCmd[@]}" << "EOF"
volumeIds=$(docker volume ls -f name=openmpf -q)
if [ ! -z "$volumeIds" ]; then
  echo "Removing openmpf volumes:"
  docker volume rm -f $volumeIds;
else
  echo "No openmpf volumes found."
fi
echo
exit
EOF
}

# forAllNodes(1: nodeIds, 2: function)
forAllNodes() {
  while read -r nodeId; do
    nodeAddr=$(docker node inspect "$nodeId" --format '{{ .Status.Addr }}')
    echo
    echo "Connecting to $nodeAddr ..."

    if [ "$askPass" = 0 ]; then
      sshCmd=(ssh -oStrictHostKeyChecking=no "$nodeAddr" /bin/bash)
    else
      sshCmd=(sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" /bin/bash)
    fi

    $2 "$sshCmd"
  done <<< "$1"
}

askPass=0
removeDbVolume=0
removeAllVolumes=0
removeSharedData=0

if [ $# -eq 1 ]; then
  parseVolumeType "$1"
elif [ $# -eq 2 ]; then
  if [ "$1" == "--ask-pass" ]; then
    askPass=1
    parseVolumeType "$2"
  else
    parseVolumeType "$1"
    parseRemoveSharedData "$2"
  fi
elif [ $# -eq 3 ]; then
  if [ "$1" == "--ask-pass" ]; then
    askPass=1
  else
    printUsage
  fi
  parseVolumeType "$2"
  parseRemoveSharedData "$3"
else
  printUsage
fi

# Abort early if the helper script doesn't exist.
scriptPath="$(dirname $0)/docker-swarm-clean-shared-volume.sh"
if [ ! -f "$scriptPath" ]; then
  echo "Could not find \"$scriptPath\". Aborting."
  exit 1
fi

if [ "$askPass" == 1 ]; then
  read -s -p "Enter SSH user: " sshUser
  echo

  read -s -p "Enter SSH password: " sshPass
  echo
  echo
fi

# Check if stack exists. If so, remove it.
if docker stack ps openmpf > /dev/null 2>&1; then
  # The following command does not always remove the stopped containers.
  # Refer to https://github.com/moby/moby/issues/32620.
  # According to the official docs: "Services, networks, and secrets associated with the stack will be removed."
  docker stack rm openmpf

  # Give the previous command time to work.
  sleep 10
fi

nodeIds=$(docker node ls | sed -n '1!p' | cut -d ' ' -f 1)

forAllNodes "$nodeIds" cleanupContainers

# Remove the shared data before the shared volume is removed.
echo
if [ "$removeSharedData" == 1 ]; then
  # Remove everything.
  sh "$scriptPath" || exit 1 # abort if script fails
else
  # Minimally, remove the "nodes" directory.
  sh "$scriptPath" "nodes" || exit 1 # abort if script fails
fi
echo

if [ "$removeAllVolumes" == 1 ]; then
  forAllNodes "$nodeIds" cleanupAllVolumes
elif [ "$removeDbVolume" == 1 ]; then
  forAllNodes "$nodeIds" cleanupDbVolume
fi
