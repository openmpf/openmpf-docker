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
    echo "docker-retag-push-images.sh [--clean-old-tags] [--push] [--old-registry] --old-tag [--new-registry] --new-tag"
    echo "docker-retag-push-images.sh [--clean-old-tags] --push [--registry] --tag"
    exit 1
}

#cleanOldTags(1: images)
cleanOldTags() {
    for image in "$@"; do
        allTagsStr="$(docker inspect $image --format={{.RepoTags}})"
        allTagsStr="${allTagsStr:1:-1}" # strip off brackets
        declare -a allTags=( $allTagsStr ) # split on whitespace
        for tag in "${allTags[@]}"; do
            if []; then
                
            fi
            echo "$tag" # DEBUG
        done
    done
}

# pushImages(1: images)
pushImages() {
    for image in "$@"; do
        command=(docker push "$image")
        echo "${command[@]}"
        #"${command[@]}"
    done
}

cleanOldTags=0
push=0
while [ $# -gt 0 ]; do
    case "$1" in
        --clean-old-tags)
            cleanOldTags=1
            ;;
        --push)
            push=1
            ;;
        --old-registry)
            oldReg="$2"
            shift
            ;;
        --old-tag)
            oldTag="$2"
            shift
            ;;
        --new-registry)
            newReg="$2"
            shift
            ;;
        --new-tag)
            newTag="$2"
            shift
            ;;
        -*)
            echo "Bad option \"$1\""
            printUsage
            ;;
        *)
            echo "Unexpected argument \"$1\""
            printUsage
            ;;
    esac
    shift
done

if [ -z "$oldTag" ]; then
    printUsage
fi

if [ -z "$newTag" ] && [ "$push" == 0 ]; then
    printUsage
fi

if [ "${oldReg: -1}" == "/" ]; then
    oldReg="${oldReg:0:-1}"
fi

if [ "${newReg: -1}" == "/" ]; then
    newReg="${newReg:0:-1}"
fi

if [ -z "$oldReg" ]; then
    filter="--filter=reference=openmpf*:$oldTag"
else
    filter="--filter=reference=$oldReg/openmpf*:$oldTag"
fi

readarray -t oldImages < <(docker images "$filter" --format="{{.Repository}}:{{.Tag}}")

if [ "${#oldImages[@]}" -eq 0 ]; then
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

if [ ! -z "$newTag" ]; then
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
        command=(docker tag "$oldImage" "$newImage")
        echo "${command[@]}"
        #"${command[@]}"
        newImages+=("$newImage")
    done
fi

if [ "$cleanOldTags" == 1 ]; then
    echo
    echo "Cleaning old tags:"
    if [ "${#newImages[@]}" -ne 0 ]; then
        cleanOldTags "${newImages[@]}"
    else
        cleanOldTags "${oldImages[@]}"
    fi
fi

if [ "$push" == 1 ]; then
    echo
    echo "Pushing images:"
    if [ "${#newImages[@]}" -ne 0 ]; then
        pushImages "${newImages[@]}"
    else
        pushImages "${oldImages[@]}"
    fi
fi
