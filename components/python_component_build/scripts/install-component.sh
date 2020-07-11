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

set -o errexit -o pipefail -o xtrace

src_dir="${SRC_DIR:-/home/mpf/component_src}"

descriptor_path=$src_dir/plugin-files/descriptor/descriptor.json

if [ ! -e "$descriptor_path" ]; then
    echo "Error: Expected $descriptor_path to exist. Did you forget to COPY or bind mount your component source code?"
    exit 3
fi

component_name=$(python3 -c "import json; print(json.load(open('$descriptor_path'))['componentName'])")
mkdir --parents "$MPF_HOME/plugins/$component_name"

if [ -e "$src_dir/setup.py" ]; then
    echo 'Installing setuptools plugin'
    cp --recursive "$src_dir"/plugin-files/* "$MPF_HOME/plugins/$component_name/"


    if [ -d "$src_dir/plugin-files/wheelhouse" ]; then
        "$COMPONENT_VIRTUALENV/bin/pip3" install \
            --find-links "$src_dir/plugin-files/wheelhouse" \
            --no-cache-dir "$src_dir"
    else
        "$COMPONENT_VIRTUALENV/bin/pip3" install \
            --no-cache-dir "$src_dir"
    fi
else
    echo 'Installing basic component'
    cp --recursive "$src_dir"/* "$MPF_HOME/plugins/$component_name/"
fi

