#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2019 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2019 The MITRE Corporation                                      #
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

set -Ee

intExit() {
    # Kill all subprocesses (all processes in the current process group)
    kill -HUP -$$
}

hupExit() {
    # HUP'd (probably by intExit)
    echo
    echo "Interrupted"
    exit
}

trap hupExit HUP
trap intExit INT

# spinner(header, pids)
spinner() {
  local delay=5.0

  header="$1"
  pids="$2"
  cont=1

  echo -n "$header ..."

  while [ "$cont" = 1 ]; do
    cont=0
    for pid in "${pids[@]}"; do
      if ps a | awk '{print $1}' | grep -q "${pid}"; then
        cont=1
        break
      fi
    done
    echo -n "."
    sleep "$delay"
  done

  echo " done"
  echo
}

echo "This will take some time. Please be patient."
echo

echo "Images to load:"
pids=()
for tgz in *.tar.gz; do
  echo "  $tgz"
  docker load -q -i "$tgz" >> /dev/null &
  pids+=($!)
done
echo

spinner "Loading images" "$pids"
