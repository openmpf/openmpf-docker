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
  echo "docker-swarm-logs.sh <--all-logs|--node-manager-logs> <--archive <output-path>|--no-archive> [--remove-originals]"
  exit -1
}

# parseLogType(1: logType)
parseLogType() {
    if [ "$1" = "--all-logs" ]; then
        allLogs=1
    elif [ "$1" = "--node-manager-logs" ]; then
        nodeManagerLogs=1
    else
        printUsage
    fi
}

# parseRemoveOriginals(1: option)
parseRemoveOriginals() {
    if [ "$1" = "--remove-originals" ]; then
        removeOriginals=1
    else
        printUsage
    fi
}

# getTimestamp(1: retval)
getTimestamp() {
    # Use ISO-8601 timestamp. Replace colon with period since colon may cause issues during extraction.
    eval "$1='$(date --iso-8601=s | sed 's/:/./g')'"
}

allLogs=0
nodeManagerLogs=0
outputPath=""
removeOriginals=0

if [ $# -eq 3 ] || [ $# -eq 4 ]; then
    parseLogType "$1"
    if [ "$2" = "--archive" ]; then
        outputPath="$3"
        if [ $# -eq 4 ]; then
            parseRemoveOriginals "$4"
        fi
    elif [ "$2" = "--no-archive" ]; then
        parseRemoveOriginals "$3"
    else
        printUsage
    fi
else
    printUsage
fi

# Create a helper container that mounts the shared volume. Use an image that we know exists.
# The exact image is not important.
containerId="$(docker run -d --rm --entrypoint bash -v openmpf_shared_data:/data --name openmpf_helper redis -c 'sleep infinity')"

if [ "$nodeManagerLogs" = 1 ]; then
    findNameOption="-name 'node_manager_id_*'"
fi

logDirs=()
while IFS=  read -r -d $'\0'; do
    logDirs+=("$REPLY")
done < <(docker exec openmpf_helper bash -c "find /data/logs -type d -mindepth 1 -maxdepth 1 $findNameOption -print0")

if [ "${#logDirs[@]}" = 0 ]; then
    if [ "$allLogs" = 1 ]; then
        echo "No log files found in the shared directory."
    else
        echo "No log files in the shared directory match the specified criteria."
    fi
    docker rm -f openmpf_helper > /dev/null
    exit 0
fi

echo "Found the following log directories in the shared volume:"
for logDir in "${logDirs[@]}"; do
    echo "  $logDir"
done

if [ ! -z  "$outputPath" ]; then
    getTimestamp timestamp
    if [ "$allLogs" = 1 ]; then
        archivePath="$outputPath/openmpf-logs.$timestamp"
    elif [ "$nodeManagerLogs" = 1 ]; then
        archivePath="$outputPath/openmpf-node-manager-logs.$timestamp"
    fi

    mkdir -p "$archivePath"

    echo
    echo "Copying the log directories from the shared volume."
    for logDir in "${logDirs[@]}"; do
        docker cp openmpf_helper:"$logDir" "$archivePath"
    done

    tar -czf "$archivePath.tar.gz" -C "$(dirname $archivePath)" "$(basename $archivePath)"
    rm -rf "$archivePath"

    echo
    echo "Generated $archivePath.tar.gz"
fi

if [ "$removeOriginals" = 1 ]; then
    echo
    echo "Removing the original log directories from the shared volume."
    docker exec openmpf_helper bash -c "find /data/logs -type d -mindepth 1 -maxdepth 1 $findNameOption -exec rm -rf {} \;"
fi

docker rm -f openmpf_helper > /dev/null