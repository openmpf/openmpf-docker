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

printUsage() {
  echo "Usages:"
  echo "docker-swarm-remove-images.sh [--ask-pass] [--dry-run] -t <partial-image-tag>"
  echo "docker-swarm-remove-images.sh [--ask-pass] [--dry-run] -n <partial-image-name>"
  exit -1
}

askPass=0
dryRun=0

if [ $# = 2 ]; then
  mode="$1"
  searchStr="$2"
elif [ $# = 3 ]; then
  if [ "$1" = "--ask-pass" ]; then
    askPass=1
  elif [ "$1" = "--dry-run" ]; then
    dryRun=1
  else
    printUsage
  fi
  mode="$2"
  searchStr="$3"
elif [ $# = 4 ]; then
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
  mode="$3"
  searchStr="$4"
else
  printUsage
fi

# Example output of "docker image ls":
# REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
# openmpf-docker_workflow_manager   latest              0bb20302dd48        44 hours ago        3.31GB
# mpf_build                         latest              aa1729292884        44 hours ago        12.8GB
nameColIndex=1
tagColIndex=2
imageIdColIndex=3

if [ "$mode" = "-t" ]; then
  colIndex=$tagColIndex
elif [ "$mode" = "-n" ]; then
  colIndex=$nameColIndex
else
  printUsage
fi

nodeIds=$(docker node ls | sed -n '1!p' | cut -d ' ' -f 1)

while read -r nodeId; do
  nodeAddr=$(docker node inspect "$nodeId" --format '{{ .Status.Addr }}')
  echo
  echo "Connecting to $nodeAddr ..."

  if [ $askPass = 0 ]; then
    listing=$(ssh -oStrictHostKeyChecking=no "$nodeAddr" docker image ls)
  else
    listing=$(sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" docker image ls)
  fi

  # Remove column names
  content=$(echo "$listing" | sed -n '1!p')

  # Parse out elements to search
  allElements=$(echo "$content" | tr -s ' ' | cut -d ' ' -f $colIndex)

  # Search elements
  foundElements=$(echo "$allElements" | grep "$searchStr")

  if [ -z "$foundElements" ]; then
    echo "No images found."
    exit 0
  fi

  foundRowIndices=$(echo "$allElements" | grep "$searchStr" -n | cut -d ':' -f 1)

  while read -r line; do
    rowId=$(($line + 1))
    row=$(echo "$listing" | sed -n -e "$rowId"p)
    rowsToRemove+=$row"\n"
    imageId=$(echo "$row" | tr -s ' ' | cut -d ' ' -f $imageIdColIndex)
    imageIdsToRemove+=$imageId" "
  done <<< "$foundRowIndices"

  echo "Images to remove:"
  echo -e "$rowsToRemove"

  if [ $dryRun = 0 ]; then
    echo "Removing images ..."

    if [ $askPass = 0 ]; then
      listing=$(ssh -oStrictHostKeyChecking=no "$nodeAddr" docker image rm -f $imageIdsToRemove)
    else
      listing=$(sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" docker image rm -f $imageIdsToRemove)
    fi
  fi

done <<< "$nodeIds"
