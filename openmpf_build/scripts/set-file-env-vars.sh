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


if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    # Without sourcing, a subshell will be created and the subshell's environment variables will
    # be changed, rather than the calling script's environment variables.
    >&2 echo "error: This script must be sourced."
    exit 3
fi


# For each environment variable with a name ending in _LOAD_FROM_FILE, create a new one by
# removing the suffix and setting the value to the contents of the file path from the original.
# Maps SOME_NAME_LOAD_FROM_FILE=/path/to/file to SOME_NAME=<content of /path/to/file>
set_file_env_vars() {
    # Make "set -o" options local to this function.
    local -
    set -o errexit -o pipefail

    # Create an array where each element is a string like VARNAME=VALUE.
    readarray -d '' -t env_vars < <(printenv --null)

    for env_pair in "${env_vars[@]}"; do
        # Remove the first = and everything that follows. %% is remove long suffix.
        # It is used because the value of the environment variable might also contain =.
        local var_name=${env_pair%%=*}
        # Remove _LOAD_FROM_FILE from the variable name if it exists.
        local target_env_var=${var_name%_LOAD_FROM_FILE}
        if [[ $var_name == "$target_env_var" ]]; then
            # Removing the suffix from var_name did not change the value so the suffix was not
            # present.
            continue
        fi

        # "$target_env_var" is the name of the environment variable that will modified.
        # "${!target_env_var}" is the value of that environment variable.
        if [[ ${!target_env_var} ]]; then
            echo "error: $target_env_var is already set to ${!target_env_var}"
            exit 4
        fi
        # Remove the first = and everything before it. # is remove short prefix.
        local var_value_path=${env_pair#*=}
        echo "Setting the $target_env_var environment variable to the contents of the $var_value_path file."

        # Need to use temporary value so that the script exits when the file is missing.
        # Using $() in the same line as local or export does not exit on error.
        local temp_file_contents
        temp_file_contents="$(< "$var_value_path")"
        export "$target_env_var"="$temp_file_contents"
    done
}

>&2 set_file_env_vars
unset -f set_file_env_vars
