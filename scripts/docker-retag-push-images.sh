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
    echo "docker-retag-push-images.sh [--dry-run] [--remove-other-tags] [--push] [--registry] --tag [--new-registry] --new-tag"
    echo "docker-retag-push-images.sh [--dry-run] [--remove-other-tags] --push [--registry] --tag"
    exit 1
}

# pushImages(1: images)
pushImages() {
    for image in "$@"; do
        command=(docker push "$image")
        echo "${command[@]}"
        if [ "$dryRun" == 0 ]; then
            "${command[@]}"
        fi
    done
}

dryRun=0
removeOtherTags=0
push=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            dryRun=1
            ;;
        --remove-other-tags)
            removeOtherTags=1
            ;;
        --push)
            push=1
            ;;
        --registry)
            oldReg="$2"
            shift
            ;;
        --tag)
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
    echo "Missing --tag."
    printUsage
fi

if [ "$newReg" ] && [ -z "$newTag" ]; then
    echo "When specifying --new-registry you must also specify --new-tag."
    printUsage
fi

if [ -z "$newTag" ] && [ "$push" == 0 ]; then
    echo "Since --new-tag is missing we assume you want to only push images, not retag them, but you're missing --push."
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
        if [ "$dryRun" == 0 ]; then
            "${command[@]}"
        fi
        newImages+=("$newImage")
    done
fi

if [ "$removeOtherTags" == 1 ]; then
    echo
    echo "Removing other tags:"
    for ((i = 0; i < "${#oldImages[@]}"; i++)); do
        readarray -t allTags < <(docker inspect "${oldImages[i]}" '--format={{join .RepoTags "\n"}}')
        if [ "${#newImages[@]}" -ne 0 ]; then
            keepImage="${newImages[i]}"
        else
            keepImage="${oldImages[i]}"
        fi
        for tag in "${allTags[@]}"; do
            if [ "$tag" != "$keepImage" ]; then
                command=(docker rmi "$tag")
                echo "${command[@]}"
                if [ "$dryRun" == 0 ]; then
                    "${command[@]}"
                fi
            fi
        done
    done
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

echo
echo "Done"
