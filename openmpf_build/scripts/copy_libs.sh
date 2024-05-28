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

NEED_TO_CHECK_MISSING_LIBS=true

main() {
    if [[ $# -lt 3 ]]; then
        echo 'Too few arugments.'
        echo "Usage: $0 <elf-file> <target-libs-dir> <source-libs-dir>"
        exit 1
    fi

    while [[ $NEED_TO_CHECK_MISSING_LIBS ]]; do
        copy_libs "$@"
    done
}

copy_libs() {
    local lib_file=$1
    local extra_libs_install_dir=$2
    local lib_copy_src_dir=$3
    NEED_TO_CHECK_MISSING_LIBS=''

    readarray -t ldd_lines < <(run_ldd "$lib_file" "$extra_libs_install_dir")

    for line in "${ldd_lines[@]}"; do
        local lib_name
        lib_name=$(get_missing_lib_name "$line")
        if [[ $lib_name ]]; then
            # The library we are copying might also have dependencies, so we will need to run
            # ldd again once the library is copied in.
            NEED_TO_CHECK_MISSING_LIBS=true
            echo "cp '$lib_copy_src_dir/$lib_name' '$extra_libs_install_dir/$lib_name'"
            cp "$lib_copy_src_dir/$lib_name" "$extra_libs_install_dir/$lib_name"
        fi
    done
}

ORIGINAL_LD_LIBRARY_PATH=$LD_LIBRARY_PATH

run_ldd() {
    local lib_file=$1
    local extra_libs_install_dir=$2

    local ld_lib_path=$extra_libs_install_dir
    if [[ $ORIGINAL_LD_LIBRARY_PATH ]]; then
        ld_lib_path=$ld_lib_path:$ORIGINAL_LD_LIBRARY_PATH
    fi
    LD_LIBRARY_PATH="$ld_lib_path" ldd "$lib_file"
}

# The format for the lines with missing libraries is: "  libname.so => not found"
NOT_FOUND_PATTERN='([^[:space:]=]+) => not found'

get_missing_lib_name() {
    ldd_line=$1
    if [[ $ldd_line =~ $NOT_FOUND_PATTERN ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

main "$@"
