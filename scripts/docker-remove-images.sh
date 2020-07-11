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

printUsage() {
  echo "Usages:"
  echo "docker-remove-images.sh [--dry-run] <--partial|--exact> -n <image-name>"
  echo "docker-remove-images.sh [--dry-run] <--partial|--exact> -t <image-tag>"
  exit 1
}

if [ $# = 3 ]; then
  dryRun=0
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
  if [ "$1" != "--dry-run" ]; then
    printUsage
  fi
  dryRun=1
  if [ "$2" == "--partial" ]; then
    exact=0
  elif [[ "$2" == "--exact" ]]; then
    exact=1
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

listing=$(docker image ls)

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
  exit 0
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
  docker image rm -f $imagesToRemove
fi
