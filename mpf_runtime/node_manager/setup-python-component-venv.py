#!/usr/bin/python

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
# distributed under the License is distributed don an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

import json
import sys
import os
import os.path
import subprocess

comp_dir = sys.argv[1]
json_file = open(comp_dir + "/descriptor/descriptor.json", "r")
json_data = json.load(json_file)

if json_data["sourceLanguage"] == "python":
    wheelhouse_dir = comp_dir + "/wheelhouse"
    venv_dir = comp_dir + "/venv"

    if os.path.isdir(wheelhouse_dir):
        print "Setup virtualenv for Python setuptools-based component " + json_data["componentName"]
        comp_lib_name = json_data["batchLibrary"]
        if not comp_lib_name:
            comp_lib_name = json_data["streamLibrary"]
        subprocess.call(["pip", "install", "--find-links", wheelhouse_dir, "--no-index", comp_lib_name])
    else:
        print "Setup virtualenv for basic Python component " + json_data["componentName"]
        subprocess.call(["pip", "install", "--find-links", os.environ['MPF_HOME'] + "/python/wheelhouse", "--no-index", "mpf_component_api"])

    subprocess.call(["virtualenv", "-p", "python2.7", venv_dir])

json_file.close()
