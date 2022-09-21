#!/usr/bin/env bash

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2022 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2022 The MITRE Corporation                                      #
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

if [ ! "$ACTIVE_MQ_BROKER_URI" ]; then
    export ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
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
# Configure HTTP or HTTPS                                                      #
################################################################################

if [ "$KEYSTORE_PASSWORD" ]; then
    export CATALINA_OPTS="$CATALINA_OPTS -Dtransport.guarantee='CONFIDENTIAL' -Dweb.rest.protocol='https'"
    python3 << EndOfPythonScript
import xml.etree.ElementTree as ET
import os

keystore_password = os.getenv('KEYSTORE_PASSWORD')
server_xml_path = '/opt/apache-tomcat/conf/server.xml'

tree_builder = ET.TreeBuilder(insert_comments=True)
tree = ET.parse(server_xml_path, ET.XMLParser(target=tree_builder))
https_connector = tree.find('./Service/Connector[@sslProtocol="TLS"][@scheme="https"]')

if https_connector is None:
    print('Enabling HTTPS')
    ssl_connector_element = ET.Element('Connector',
        SSLEnabled='true',
        acceptCount='100',
        clientAuth='false',
        disableUploadTimeout='true',
        enableLookups='false',
        keystoreFile='/run/secrets/https_keystore',
        keystorePass=keystore_password,
        maxThreads='25',
        port='8443',
        protocol='org.apache.coyote.http11.Http11NioProtocol',
        scheme='https',
        secure='true',
        sslProtocol='TLS')
    ssl_connector_element.tail = '\n\n    '
    tree.find('Service').insert(8, ssl_connector_element)
    tree.write(server_xml_path)
else:
    print('HTTPS already enabled')
EndOfPythonScript
else
    export CATALINA_OPTS="$CATALINA_OPTS -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
fi


################################################################################
# Start Tomcat                                                                 #
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


echo 'Waiting for ActiveMQ to become available ...'
# --spider makes wget use a HEAD request
# wget exits with code 6 when there is an authentication error. This is expected because the
# ActiveMQ status page requires authentication. We are just using the request to verify ActiveMQ
# is running so there is no need to authenticate.
until wget --spider --tries 1 "http://$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1 || [ $? -eq 6 ]; do
    echo 'ActiveMQ is unavailable. Sleeping.'
    sleep 5
done
echo 'ActiveMQ is up'

set -o xtrace


exec /opt/apache-tomcat/bin/catalina.sh run
