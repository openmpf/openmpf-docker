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

set -o xtrace

# The following command does not always remove the stopped containers;
# however, it should remove networks.
# Refer to https://github.com/moby/moby/issues/32620.
docker stack rm openmpf

containerIds=$(docker ps -a -f name=openmpf_ -q)

set +o xtrace
if [ ! -z "$containerIds" ]; then
  set -o xtrace
  docker container rm -f $containerIds
fi

set -o xtrace

volumeIds=$(docker volume ls -f name=openmpf_ -q)

set +o xtrace
if [ ! -z "$volumeIds" ]; then
  set -o xtrace
  docker volume rm -f $volumeIds
fi

# TODO: Remove containers and volumes on every node in the cluster.
