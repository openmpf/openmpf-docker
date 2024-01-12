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

set -o errexit -o pipefail -o xtrace


################################################################################
# Initial Setup                                                                #
################################################################################

# If empty, unset MPF_VERSION so that the default value is used by the WFM.
if [ -z "$MPF_VERSION" ]; then
    unset MPF_VERSION
fi

################################################################################
# Custom Steps                                                                 #
################################################################################

# If this is a custom build, run the custom entrypoint steps.
if [ -f /scripts/docker-custom-entrypoint.sh ]; then
    /scripts/docker-custom-entrypoint.sh
fi

################################################################################
# Configure users                                                              #
################################################################################

rm -f "$MPF_HOME/config/user.properties"

if [ -f /run/secrets/user_properties ]
then
    mkdir -p "$MPF_HOME/config"
    ln -s /run/secrets/user_properties "$MPF_HOME/config/user.properties"
fi
# else, the user.properties template will be moved to
# "$MPF_HOME/config/user.properties" by the WFM


################################################################################
# Import CA Certs                                                              #
################################################################################

IFS=':' read -r -a ca_certs <<< "$MPF_CA_CERTS"
for cert in "${ca_certs[@]}"; do
    # If there are leading colons, trailing colons, or two colons in a row, $cert wil contain the empty string.
    [ ! "$cert" ] && continue

    extension=${cert##*.}
    cert_file_name=$(basename "$cert")
    # update-ca-certificates will ignore files that don't end .crt, so we append it to the file
    # name when it is missing.
    [ "$extension" != crt ] && cert_file_name=$cert_file_name.crt
    cp "$cert" "/usr/local/share/ca-certificates/$cert_file_name"
    certs_added=1
done
[ "$certs_added" ] && update-ca-certificates


################################################################################
# Start Workflow Manager
################################################################################

echo 'Waiting for PostgreSQL to become available ...'
# Expects a JDBC_URL to be a url like "jdbc:postgresql://db:5432/mpf",
# or "jdbc:postgresql://db:5432/mpf?option1=value1&option2=value2"
# Regex converts: <anything>://<hostname>:<port number>/<anything> -> <hostname>:<port number>
if [[ $JDBC_URL =~ .+://([^/]+:[[:digit:]]+) ]]; then
    jdbc_host_port=${BASH_REMATCH[1]}
    /scripts/wait-for-it.sh "$jdbc_host_port" --timeout=0
else
    echo "Error the value of the \$JDBC_URL environment variable contains the invalid value of \"$JDBC_URL\"." \
         "Expected a url like: jdbc:postgresql://db:5432/mpf"
    exit 3
fi
echo 'PostgreSQL is available'

set +o xtrace


# Wait for Redis service.
echo 'Waiting for Redis to become available ...'
# From https://stackoverflow.com/a/39214806
until [ +PONG = "$( (exec 8<>/dev/tcp/redis/6379 && echo -e 'PING\r\n' >&8 && head -c 5 <&8; exec 8>&-) 2>/dev/null )" ]; do
    echo 'Redis is unavailable. Sleeping.'
    sleep 5
done
echo 'Redis is up'



if [ "$KEYSTORE_PASSWORD" ]; then
    echo Enabling HTTPS
    set -o xtrace
    exec java -Dsecurity.require-ssl=true -Dserver.port=8443 \
            -Dserver.ssl.key-store=/run/secrets/https_keystore  \
            -Dserver.ssl.key-store-password="$KEYSTORE_PASSWORD" \
            org.mitre.mpf.Application
else
    set -o xtrace
    exec java org.mitre.mpf.Application
fi
