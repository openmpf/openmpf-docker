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

# TODO: Filter on both name and tag.

printUsage() {
  echo "Usages:"
  echo "docker-swarm-remove-images.sh [--ask-pass] [--dry-run] <--partial|--exact> -n <image-name>"
  echo "docker-swarm-remove-images.sh [--ask-pass] [--dry-run] <--partial|--exact> -t <image-tag>"
  exit 1
}

askPass=0
dryRun=0

if [ $# = 3 ]; then
  if [ "$1" == "--partial" ]; then
    exact=0
  elif [[ "$1" == "--exact" ]]; then
    exact=1
  else
    printUsage
  fi
  mode="$2"
  searchStr="$3"
elif [ $# = 4 ]; then
  if [ "$1" = "--ask-pass" ]; then
    askPass=1
  elif [ "$1" = "--dry-run" ]; then
    dryRun=1
  else
    printUsage
  fi
  if [ "$2" == "--partial" ]; then
    exact=0
  elif [[ "$2" == "--exact" ]]; then
    exact=1
  else
    printUsage
  fi
  mode="$3"
  searchStr="$4"
elif [ $# = 5 ]; then
  if [ "$1" = "--ask-pass" ]; then
    askPass=1
  else
    printUsage
  fi
  if [ "$2" = "--dry-run" ]; then
    dryRun=1
  else
    printUsage
  fi
  if [ "$3" == "--partial" ]; then
    exact=0
  elif [[ "$3" == "--exact" ]]; then
    exact=1
  else
    printUsage
  fi
  mode="$4"
  searchStr="$5"
else
  printUsage
fi

# Example output of "docker image ls":
# REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
# openmpf_workflow-manager          latest              0bb20302dd48        44 hours ago        3.31GB
# openmpf_build                     latest              aa1729292884        44 hours ago        12.8GB
nameColIndex=1
tagColIndex=2

if [ "$mode" = "-t" ]; then
  colIndex=$tagColIndex
elif [ "$mode" = "-n" ]; then
  colIndex=$nameColIndex
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
  echo
  echo "Connecting to $nodeAddr ..."

  if [ $askPass = 0 ]; then
    listing=$(ssh -oStrictHostKeyChecking=no "$nodeAddr" docker image ls < /dev/null)
  else
    listing=$(sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" docker image ls < /dev/null)
  fi

  # Remove column names
  content=$(echo "$listing" | sed -n '1!p')

  # Parse out elements to search
  allElements=$(echo "$content" | tr -s ' ' | cut -d ' ' -f $colIndex)

  # Search elements
  if [[ $exact = 1 ]]; then
    foundRowIndices=$(echo "$allElements" | grep ^"$searchStr"$ -n | cut -d ':' -f 1)
  else
    foundRowIndices=$(echo "$allElements" | grep "$searchStr" -n | cut -d ':' -f 1)
  fi

  if [ -z "$foundRowIndices" ]; then
    echo "No images found."
    continue
  fi

  echo "Images to remove:"
  while read -r line; do
    rowId=$(($line + 1))
    row=$(echo "$listing" | sed -n -e "$rowId"p)
    rowsToRemove+=$row"\n"
    imageName=$(echo "$row" | tr -s ' ' | cut -d ' ' -f $nameColIndex)
    imageTag=$(echo "$row" | tr -s ' ' | cut -d ' ' -f $tagColIndex)
    imageToRemove=$imageName":"$imageTag
    imagesToRemove+=$imageToRemove" "
    echo "$imageToRemove"
  done <<< "$foundRowIndices"

  if [ $dryRun = 0 ]; then
    echo
    echo "Removing images ..."

    if [ $askPass = 0 ]; then
      ssh "$nodeAddr" docker image rm -f $imagesToRemove < /dev/null
    else
      sshpass -p "$sshPass" ssh "$sshUser"@"$nodeAddr" docker image rm -f $imagesToRemove < /dev/null
    fi

    echo
  fi

done <<< "$nodeIds"
