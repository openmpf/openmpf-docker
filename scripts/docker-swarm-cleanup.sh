#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2023 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2023 The MITRE Corporation                                      #
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


main() {
    if ! options=$(getopt --name "$0"  \
            --options ajl \
            --longoptions rm-all,rm-job-output,rm-logs \
            -- "$@"); then
        print_usage
    fi
    eval set -- "$options"

    while true; do
        case "$1" in
        --rm-logs | -l )
            local remove_logs=true
            ;;
        --rm-job-output | -j )
            local remove_job_output=true
            ;;
        --rm-all | -a )
            local remove_all=true
            ;;
        -- )
            shift
            break
            ;;
        esac
        shift
    done
    if [ $# -lt 1 ]; then
        echo 'Error: The first parameter must be the name of the stack you want to clean up.'
        print_usage
    fi
    if [ $# -gt 1 ]; then
        echo "Error: multiple stacks provided: $*"
        print_usage
    fi

    local stack_name=$1
    destroy_stack "$stack_name"

    if [ "$remove_logs" ] || [ "$remove_job_output" ] || [ "$remove_all" ]; then
        clean_shared_volume "$stack_name" "$remove_logs" "$remove_job_output" "$remove_all"
    fi
}


destroy_stack() {
    local stack_name=$1
    if ! docker stack ps -q "$stack_name" &> /dev/null; then
        echo "The $stack_name stack has already been stopped."
        return
    fi

    docker stack rm "$stack_name"
    sleep 5
    while docker stack ps "$stack_name" --format 'table {{.Name}} \t {{.CurrentState}} \t {{.Node}}' 2> /dev/null; do
        echo -e '\nStack still partially up. Waiting for stack to be completely destroyed...\n'
        sleep 5
    done
}


clean_shared_volume() {
    local stack_name=$1
    local clean_logs=$2
    local clean_job_output=$3
    local remove_all=$4

    local shared_data_volume=${stack_name}_shared_data
    if ! docker volume inspect "$shared_data_volume" &> /dev/null; then
        echo "Could not clean the $shared_data_volume volume because it does not appear to exist."
        exit 2
    fi

    local files_to_clear=''
    if [ "$remove_all" ]; then
        files_to_clear='*'
    else
        if [ "$clean_logs" ]; then
            files_to_clear+='logs/* '
        fi
        if [ "$clean_job_output" ]; then
            files_to_clear+='output-objects/* artifacts/* tmp/* markup/* remote-media/*'
        fi
    fi

    echo "Deleting the following files in the $shared_data_volume volume: $files_to_clear"

    # Create a helper container that mounts the shared volume. Use an image that we know exists on the user's machine.
    # The exact image is not important.
    docker run --rm -v "$shared_data_volume:/mpf_data" --workdir /mpf_data --entrypoint sh redis:alpine -c \
            "rm -rf $files_to_clear" ||:
}


print_usage() {
    echo "Usage:
$0 <stack-name> [--rm-logs|-l] [--rm-job-output|-j] [--rm-all|-a]

Stops the specified Docker stack. Waits for all of the services in the stack to exit.
Optionally clears parts of the shared data volume.
    --rm-logs: rm -rf logs/*
    --rm-job-output: rm -rf output-objects/* artifacts/* tmp/* markup/* remote-media/*
    --rm-all: rm -rf share/*
"
    exit 1
}

main "$@"

