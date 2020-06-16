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
############################################################################

set -o errexit -o pipefail

printUsage() {
    echo "Usage: $0 [--rm] [-o <output-dir>]"
    echo "    --rm removes logs from the shared data volume."
    echo "    -o stores the logs in a .tar.gz on the host file system."
    exit 1
}


while [ "$1" ]; do
    case "$1" in
    --rm)
        remove_logs=true
        ;;
    -o)
        if [ ! "$2" ]; then
            echo 'A directory must be provided when using -o'
            printUsage
        fi
        output_dir=$2
        shift
        ;;
    *)
        echo "Unknown option: $1"
        printUsage
        ;;
    esac
    shift
done

if [ ! "$remove_logs" ] && [ ! "$output_dir" ]; then
    printUsage
fi

# Create a helper container that mounts the shared volume. Use an image that we know exists on the user's machine.
# The exact image is not important.
container_id=$(docker create -v openmpf_shared_data:/data --entrypoint sh redis:alpine -c 'rm -r /data/logs/*')
trap 'docker rm -f $container_id > /dev/null' EXIT

if [ "$output_dir" ]; then
    # Use ISO-8601 timestamp. Replace colon with period since colon may cause issues during extraction.
    timestamp=$(date --iso-8601=s | sed 's/:/./g')
    archive_name="$output_dir/openmpf-logs.$timestamp.tar.gz"

    docker cp "${container_id}:/data/logs" - | gzip > "$archive_name"
fi

if [ "$remove_logs" ]; then
    docker start -a "$container_id"
fi
