#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2024 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2024 The MITRE Corporation                                      #
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

# Install CA certificates specified by colon delimited paths in the MPF_CA_CERTS environment
# variable.
install_certs() {
    IFS=':' read -r -a ca_certs <<< "$MPF_CA_CERTS"
    for cert in "${ca_certs[@]}"; do
        # If there are leading colons, trailing colons, or two colons in a row, $cert wil contain
        # the empty string.
        [[ ! $cert ]] && continue

        echo "Installing certificate: $cert"
        extension=${cert##*.}
        cert_file_name=$(basename "$cert")
        # update-ca-certificates will ignore files that don't end .crt, so we append it to the file
        # name when it is missing.
        [[ $extension != crt ]] && cert_file_name=$cert_file_name.crt
        cp -- "$cert" "/usr/local/share/ca-certificates/$cert_file_name"
        certs_added=1
    done
    if [[ $certs_added ]]; then
        update-ca-certificates
    fi
}
>&2 install_certs
