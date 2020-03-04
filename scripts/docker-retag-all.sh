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
  echo "docker-retag-all.sh <old-registry> <old-tag> <new-registry> <new-tag>"
  echo "docker-retag-all.sh <old-tag> <new-registry> <new-tag>"
  echo "docker-retag-all.sh <old-tag> <new-tag>"
  exit 1
}

if [ $# -eq 4 ]; then
  oldRegistry=$1
  oldTag=$2
  newRegistry=$3
  newTag=$4
elif [ $# -eq 3 ]; then
  oldTag=$1
  newRegistry=$2
  newTag=$3
elif [ $# -eq 2 ]; then
  oldTag=$1
  newTag=$2
else
  printUsage
fi

if [ "${oldRegistry: -1}" == "/" ]; then
  oldRegistry="${oldRegistry:0:$length-1}"
fi

if [ "${newRegistry: -1}" == "/" ]; then
  newRegistry="${newRegistry:0:$length-1}"
fi

if [ -z "$oldRegistry" ]; then
  filter="--filter=reference=openmpf**:$oldTag"
else
  filter="--filter=reference=$oldRegistry/openmpf**:$oldTag"
fi

IFS=' ' read -r -a oldImages <<< $(docker images "$filter" --format="{{.Repository}}:{{.Tag}}")

if [ -z "$oldImages" ]; then
  echo "No images found."
  exit 1
fi

echo "Found images:"
echo
docker images "$filter"

echo
read -p "Continue [y/N]? " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo
  echo "Terminated by user"
  exit 0
fi

echo
echo "Retagging images:"
for oldImage in "${oldImages[@]}"; do
  repo="${oldImage%:*}"
  name="${repo##*/}"
  if [ -z "$newRegistry" ]; then
      command="docker tag $oldImage $name:$newTag"
  else
      command="docker tag $oldImage $newRegistry/$name:$newTag"
  fi
  echo "$command"
  eval "$command"
done