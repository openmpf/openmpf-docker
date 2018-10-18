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
# 2. Optionally, sshpass is used to provide a password to the ssh command.

printUsage() {
  echo "Usages:"
  echo "docker-swarm-cleanup.sh [--ask-pass]"
  exit -1
}

if [ $# -eq 0 ]; then
  askPass=0
elif [ $# -eq 1 ]; then
  if [ "$1" != "--ask-pass" ]; then
    printUsage
  fi
  askPass=1
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

# The following command does not always remove the stopped containers;
# however, it should remove networks.
# Refer to https://github.com/moby/moby/issues/32620.
docker stack rm openmpf
echo

# Give the previous command time to work.
sleep 10

nodeIds=$(docker node ls | sed -n '1!p' | cut -d ' ' -f 1)

while read -r nodeId; do
  nodeAddr=$(docker node inspect "$nodeId" --format '{{ .Status.Addr }}')
  echo
  echo "Connecting to $nodeAddr ..."

  if [ $askPass = 0 ]; then
    sshCmd=(ssh -oStrictHostKeyChecking=no "$nodeAddr" /bin/bash)
  else
    sshCmd=(sshpass -p "$sshPass" ssh -oStrictHostKeyChecking=no "$sshUser"@"$nodeAddr" /bin/bash)
  fi

"${sshCmd[@]}" << "EOF"
# set -o xtrace

containerIds=$(docker ps -a -f name=openmpf_ -q)

if [ ! -z "$containerIds" ]; then
  echo "Removing openmpf containers:"
  docker container rm -f $containerIds;
else \
  echo "No openmpf containers running."
fi
echo

recreateSharedDataVolume=0
sharedDataVolumeInfo=$(docker volume inspect openmpf_shared_data)

if [ $? -eq 0 ]; then
  recreateSharedDataVolume=-1
  sharedDataVolumeDriver=$(docker volume inspect openmpf_shared_data --format '{{ .Driver }}')

  sharedDataVolumeDevice=$(docker volume inspect openmpf_shared_data --format '{{ .Options.device }}' )

  if [ $? -eq 0 ] && [ "$sharedDataVolumeDevice" != "<no value>" ]; then
    sharedDataVolumeOtherOptions=$(docker volume inspect openmpf_shared_data --format '{{ .Options.o }}')

    if [ $? -eq 0 ] && [ "$sharedDataVolumeOtherOptions" != "<no value>" ]; then
      sharedDataVolumeType=$(docker volume inspect openmpf_shared_data --format '{{ .Options.type }}')

      if [ $? -eq 0 ] && [ "$sharedDataVolumeType" != "<no value>" ]; then
        recreateSharedDataVolume=1
      fi
    fi
  fi
fi

volumeIds=$(docker volume ls -f name=openmpf -q)

if [ ! -z "$volumeIds" ]; then
  echo "Removing openmpf volumes:"
  docker volume rm -f $volumeIds;
else
  echo "No openmpf volumes found."
fi
echo

if [ $recreateSharedDataVolume = 0 ]; then
  echo "Missing openmpf_shared_data volume. Cannot recreate."
elif [ $recreateSharedDataVolume = -1  ]; then
  echo "Unrecognized or invalid openmpf_shared_data volume. Removed, but cannot recreate:"
  echo "$sharedDataVolumeInfo"
else
  echo "Recreating volume:"
  docker volume create --driver "$sharedDataVolumeDriver" --opt type="$sharedDataVolumeType" \
    --opt o="$sharedDataVolumeOtherOptions" --opt device="$sharedDataVolumeDevice" openmpf_shared_data
fi

exit
EOF

  echo
done <<< "$nodeIds"

# TODO: Automate this, if possible.
echo
echo "IMPORTANT: Please manually remove the contents of the shared (NFS) volume."
