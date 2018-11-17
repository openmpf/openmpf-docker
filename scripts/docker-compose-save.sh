#!/usr/bin/env bash

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

set -Ee

printUsage() {
  echo "Usages:"
  echo "docker-compose-save.sh [--clean-image-names] [--include-compose-files]"
  exit -1
}

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
  local delay=0.75
  local spinstr='|/-\'

  header=$1
  pids=$2
  cont=1

  echo -n "$header ..."

  while [ $cont = 1 ]; do
    cont=0
    for pid in ${pids[@]}; do
      if ps a | awk '{print $1}' | grep -q "${pid}"; then
        cont=1
        break
      fi
    done
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done

  printf "    \b\b\b\b"
  echo " done"
  echo
}

# cleanName(imageName, retval, replaceColon)
cleanName() {
  oldName=$1
  newName=${oldName/*\//} # only keep image name and tag, remove registry and repo
  if [ $3 = 1 ]; then
    newName=${newName/:/.} # replace colon with period
  fi
  eval "$2='$newName'"
}

# getCleanImageName(imageName, retval)
getCleanImageName() {
  cleanName $1 cleanImageName 0
  eval "$2='$cleanImageName'"
}

# getFileName(imageName, retval)
getFileName() {
  cleanName $1 cleanFileName 1
  eval "$2='$cleanFileName'"
}

# generateWithoutRegistry(origFileName, newFileName)
generateWithoutRegistry() {
  sed "s/image:.*\//image: /" "$1" > "$2"
  removeBuildFields "$2"
}

# removeBuildFields(fileName)
removeBuildFields() {
  sed -i "/^.*build:.*/d" "$1"
  sed -i "/^.*context:.*/d" "$1"
  sed -i "/^.*dockerfile:.*/d" "$1"
}

echo "This will take some time. Please be patient."
echo

cleanImageNames=0
includeComposeFiles=0

if [ $# = 1 ]; then
  if [ "$1" == "--clean-image-names" ]; then
    cleanImageNames=1
  elif [ "$1" == "--include-compose-files" ]; then
    includeComposeFiles=1
  else
    printUsage
  fi
elif [ $# = 2 ]; then
  if [ "$1" == "--clean-image-names" ]; then
    cleanImageNames=1
  else
    printUsage
  fi
  if [ "$2" == "--include-compose-files" ]; then
    includeComposeFiles=1
  else
    printUsage
  fi
elif [ $# -gt 2 ]; then
  printUsage
fi

imageNames=$(docker-compose config | awk '{if ($1 == "image:") print $2;}')

outDir=openmpf-docker-images

mkdir -p $outDir
cp -R scripts $outDir

readmeFile=$outDir/README.md
rm -f $readmeFile
touch $readmeFile


echo "Load images:
\`./scripts/docker-compose-load\`

Run images:
\`docker-compose up\`

For more information, refer to https://github.com/openmpf/openmpf-docker/blob/develop/README.md." >> $readmeFile


if [ $includeComposeFiles = 1 ]; then
  echo "Including docker-compose.yml and swarm-compose.yml."
  echo
  if [ $cleanImageNames = 1 ]; then
    generateWithoutRegistry docker-compose.yml $outDir/docker-compose.yml
    generateWithoutRegistry swarm-compose.yml $outDir/swarm-compose.yml
  else
    cp docker-compose.yml $outDir; removeBuildFields $outDir/docker-compose.yml
    cp swarm-compose.yml $outDir; removeBuildFields $outDir/swarm-compose.yml
  fi
fi

if [ $cleanImageNames = 1 ]; then
  echo "Retagging images:"
  for imageName in $imageNames; do
    getCleanImageName $imageName cleanImageName
    echo "  $imageName -> $cleanImageName "
    docker tag $imageName $cleanImageName 
  done
  echo
fi

echo "Images to save:"
pids=
for imageName in $imageNames; do
  if [ $cleanImageNames = 1 ]; then
    getCleanImageName $imageName newImageName
  else
    newImageName=$imageName
  fi
  getFileName $imageName fileName
  echo "  $newImageName -> $fileName.tar"
  docker save $newImageName -o $outDir/$fileName.tar & # currently, there's no way to show progress
  pids+=($!)
done
echo

spinner "Saving images" $pids

echo "Images to gzip:"
cd $outDir
pids=
for imageName in $imageNames; do
  getFileName $imageName fileName
  echo "  $fileName.tar -> $fileName.tar.gz"
  (tar -czf $fileName.tar.gz $fileName.tar; rm -rf $fileName.tar) &
  pids+=($!)
done
cd ..
echo

spinner "Gzipping images" $pids

cd $outDir
ls -lah *.tar.gz
cd ..
echo

pids=
(tar -czf $outDir.tar.gz $outDir; rm -rf $outDir) &
pids+=($!)

spinner "Gzipping $outDir.tar.gz" $pids

ls -lah $outDir.tar.gz
echo

echo "Generated $(pwd)/$outDir.tar.gz"