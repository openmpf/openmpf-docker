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

set -o errexit -o pipefail


printUsage() {
    echo "Usages:"
    echo "docker-compose-save.sh [--clean-image-names] [--omit-compose-files]"
    exit 2
}


# spinner(header, pids)
spinner() {
    local delay=5
    local header="$1"
    shift
    local pids=("$@")

    echo -n "$header ..."

    # ps will return a success exit code as long as one of the processes is still running.
    while ps -p "${pids[@]}" > /dev/null; do
        echo -n "."
        sleep "$delay"
    done

    for pid in "${pids[@]}"; do
        # By this point all of the pids will have exited.
        # Calling wait with a single pid causes wait to return the exit code of the specified process.
        wait "$pid"
    done

    echo " done"
    echo
}

removeBuildFields() {
    docker run --rm -i mikefarah/yq yq delete - 'services.*.build'
}

cleanup() {
    jobs -pr | xargs --no-run-if-empty kill
    if [ -d "$outDir" ]; then
        rm -r "$outDir"
    fi
}


echo "This will take some time. Please be patient."
echo

cleanImageNames=0
omitComposeFiles=0

if [ $# = 1 ]; then
    if [ "$1" == "--clean-image-names" ]; then
        cleanImageNames=1
    elif [ "$1" == "--omit-compose-files" ]; then
        omitComposeFiles=1
    else
        printUsage
    fi
elif [ $# = 2 ]; then
    if [ "$1" == "--clean-image-names" ]; then
        cleanImageNames=1
    else
        printUsage
    fi
    if [ "$2" == "--omit-compose-files" ]; then
        omitComposeFiles=1
    else
        printUsage
    fi
elif [ $# -gt 2 ]; then
    printUsage
fi

outDir=openmpf-docker-images

mkdir -p "$outDir"
trap cleanup EXIT

cp -R scripts "$outDir"

echo "Load images:
\`docker load -i images.tar.gz\`

Run images:
\`docker-compose up\`

For more information, refer to https://github.com/openmpf/openmpf-docker/blob/develop/README.md." > "$outDir/README.md"

if [ "$omitComposeFiles" = 0 ]; then
    echo "Including docker-compose.yml."
    echo
    if [ "$cleanImageNames" = 1 ]; then
        sed "s/image:.*\//image: /" docker-compose.yml | removeBuildFields > "$outDir/docker-compose.yml"
    else
        removeBuildFields < docker-compose.yml > "$outDir/docker-compose.yml"
    fi
fi

readarray -t imageNames < <(docker-compose config | awk '{if ($1 == "image:") print $2;}')

newImageNames=()
if [ "$cleanImageNames" = 1 ]; then
    echo "Retagging images:"
    for imageName in "${imageNames[@]}"; do
        cleanImageName="${imageName/*\//}"
        echo "  $imageName -> $cleanImageName "
        docker tag "$imageName" "$cleanImageName"
        newImageNames+=("$cleanImageName")
    done
    echo
else
    newImageNames=("${imageNames[@]}")
fi

pids=()
docker save "${newImageNames[@]}" | gzip > "$outDir/images.tar.gz" &
pids+=($!)
spinner "Saving images" "${pids[@]}"

pids=()
tar -cf "$outDir.tar" "$outDir" &
pids+=($!)

spinner "Generating $outDir.tar" "${pids[@]}"


echo "Generated $(pwd)/$outDir.tar"
echo

if [ "$omitComposeFiles" = 0 ] || [ "$cleanImageNames" = 0 ]; then
    echo "WARNING: Please practice caution when sharing this package with others:"
    if [ "$omitComposeFiles" = 0 ]; then
        echo "- This package contains a docker-compose.yml file that may contain password and other private information."
    fi
    if [ "$cleanImageNames" = 0 ]; then
        echo "- This package contains docker images with names that may contain private registry information."
    fi
    echo
fi
