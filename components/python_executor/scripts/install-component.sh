#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2019 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2019 The MITRE Corporation                                      #
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

mkdir --parents "$MPF_HOME/plugins/plugin"

if [ -e /home/mpf/component_src/setup.py ]; then
    echo 'Installing setuptools plugin'
    cp --recursive /home/mpf/component_src/plugin-files/* "$MPF_HOME/plugins/plugin/"


    if [ -d /home/mpf/component_src/plugin-files/wheelhouse ]; then
        "$COMPONENT_VIRTUALENV/bin/pip" install \
            --find-links /home/mpf/component_src/plugin-files/wheelhouse \
            --no-cache-dir /home/mpf/component_src
    else
        "$COMPONENT_VIRTUALENV/bin/pip" install \
            --no-cache-dir /home/mpf/component_src
    fi
elif [ -e /home/mpf/component_src/descriptor/descriptor.json ]; then
    echo 'Installing basic component'
    cp --recursive /home/mpf/component_src/* "$MPF_HOME/plugins/plugin"
else
    echo 'ERROR: Expected either /home/mpf/component_src/setup.py or'\
         '/home/mpf/component_src/descriptor/descriptor.json to exist.' \
         'Did you forget to COPY or bind mount your component source code?'
    exit 3
fi

