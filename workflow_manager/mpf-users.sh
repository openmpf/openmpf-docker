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


run_user_command() {
    if [[ ! $JDBC_URL =~ .+://([^/]+:[[:digit:]]+) ]]; then
        echo "Error the value of the \$JDBC_URL environment variable contains the invalid value of \"$JDBC_URL\"." \
             "Expected a url like: jdbc:postgresql://db:5432/mpf"
        exit 3
    fi
    jdbc_host_port=${BASH_REMATCH[1]}

    local mpf_subcommand=$1
    shift

    export PYTHONPATH=/home/mpf/mpf-scripts-install
    python3 "$PYTHONPATH/bin/mpf" "$mpf_subcommand" \
        --sql-host "$jdbc_host_port" --sql-user "$POSTGRES_USER" --sql-password "$POSTGRES_PASSWORD" \
        --skip-sql-start "$@"
}

script_name=$(basename "$0")

subcommand=$1
# shift will fail if no arguments are provided so we add ||:
shift ||:

case "$subcommand" in
list)
    run_user_command list-users
    ;;
add)
    if [ $# -ne 2 ]; then
        echo 'Incorrect number of arguments. Expected 2 arguments.'
        echo "Usage: $script_name add <user> <role>"
        exit 2
    fi
    run_user_command add-user "$@"
    ;;
remove)
    if [ $# -ne 1 ]; then
        echo 'Incorrect number of arguments. Expected 1 argument.'
        echo "Usage: $script_name remove <user>"
        exit 2
    fi
    run_user_command remove-user "$@"
    ;;
change-password)
    if [ $# -ne 1 ]; then
        echo 'Incorrect number of arguments. Expected 1 argument.'
        echo "Usage: $script_name change-password <user>"
        exit 2
    fi
    run_user_command change-password "$@"
    ;;
change-role)
    if [ $# -ne 2 ]; then
        echo 'Incorrect number of arguments. Expected 2 arguments.'
        echo "Usage: $script_name change-role <user> <role>"
        exit 2
    fi
    run_user_command change-role "$@"
    ;;
*)
    cat << EndOfMessage
Invalid command
Usage:
    $script_name list
    $script_name add <user> <role>
    $script_name remove <user>
    $script_name change-password <user>
    $script_name change-role <user> <role>
EndOfMessage
    exit 1
    ;;
esac
