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
  echo "docker-retag-all.sh [--push] <old-registry> <old-tag> <new-registry> <new-tag>"
  echo "docker-retag-all.sh [--push] <old-tag> <new-registry> <new-tag>"
  echo "docker-retag-all.sh [--push] <old-tag> <new-tag>"
  exit 1
}

push=0
args=()
while test $# -gt 0
do
  case "$1" in
    --push)
      push=1
      ;;
    --*)
      echo "Bad option \"$1\""
      printUsage
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done

if [ "${#args[@]}" -eq 4 ]; then
  oldReg="${args[0]}"
  oldTag="${args[1]}"
  newReg="${args[2]}"
  newTag="${args[3]}"
elif [ "${#args[@]}" -eq 3 ]; then
  oldTag="${args[0]}"
  newReg="${args[1]}"
  newTag="${args[2]}"
elif [ "${#args[@]}" -eq 2 ]; then
  oldTag="${args[0]}"
  newTag="${args[1]}"
else
  printUsage
fi

if [ "${oldReg: -1}" == "/" ]; then
  oldReg="${oldReg:0:$length-1}"
fi

if [ "${newReg: -1}" == "/" ]; then
  newReg="${newReg:0:$length-1}"
fi

if [ -z "$oldReg" ]; then
  filter="--filter=reference=openmpf**:$oldTag"
else
  filter="--filter=reference=$oldReg/openmpf**:$oldTag"
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
echo "Tagging images:"
newImages=()
for oldImage in "${oldImages[@]}"; do
  repo="${oldImage%:*}"
  name="${repo##*/}"
  if [ -z "$newReg" ]; then
    newImage="$name:$newTag"
  else
    newImage="$newReg/$name:$newTag"
  fi
  command="docker tag $oldImage $newImage"
  echo "$command"
  eval "$command"
  newImages+=("$newImage")
done

if [ "$push" == 1 ]; then
  echo
  echo "Pushing images:"
  for newImage in "${newImages[@]}"; do
    command="docker push $newImage"
    echo "$command"
    eval "$command"
  done
fi