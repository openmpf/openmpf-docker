#!/usr/bin/bash

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
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

set -Ee -o pipefail -o xtrace

################################################################################
# Initial Setup                                                                #
################################################################################

# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*-MPF-MasterNode.list

# NOTE: In a swarm deployment, Node Manager containers are assigned hostnames of
# the form "node_manager_id_XXXXXXXXXXXX", where "XXXXXXXXXXXX" is a random hash.

# Remove nodeManagerConfig.xml so that it can be regenerated.
if grep -q "node_manager_id_*" "$MPF_HOME/share/data/nodeManagerConfig.xml"; then
  rm "$MPF_HOME/share/data/nodeManagerConfig.xml"
fi

# Archive old Node Manager logs.

dirs=()
while IFS=  read -r -d $'\0'; do
    dirs+=("$REPLY")
done < <(find "$MPF_HOME/share/logs" -type d -name "node_manager_id_*" -print0)

if [ "${#dirs[@]}" -gt 0 ]; then
  # Use ISO-8601 timestamp. Replace colon with period since colon may cause
  # issues during extraction.
  parentDir="$MPF_HOME/share/logs.bak/node-managers.pre-$(date --iso-8601=s | sed 's/:/./g')"
  mkdir -p "$parentDir"

  # Only include directories that have more than the node-manager*.log files to
  # avoid capturing Node Managers that are part of the current deployment.
  for dir in "${dirs[@]}"; do
    count=$(ls -1 -I "node-manager*" "$dir/log" | wc -l)
    if [[ "$count" -ne 0 ]]; then
      mv "$dir" "$parentDir"
    fi
  done

  count=$(ls -1 "$parentDir" | wc -l)
  if [[ "$count" -ne 0 ]]; then
    tar -czf "$parentDir.tar.gz" -C "$parentDir/.." "$(basename $parentDir)"
  fi
  rm -rf "$parentDir"
fi

# NOTE: $HOSTNAME is not known until runtime.
export JGROUPS_TCP_ADDRESS="$HOSTNAME"

################################################################################
# Custom Steps                                                                 #
################################################################################

# If this is a custom build, run the custom entrypoint steps.
if [ -f /home/mpf/docker-custom-entrypoint.sh ]; then
  /home/mpf/docker-custom-entrypoint.sh
fi

################################################################################
# Configure HTTP or HTTPS                                                      #
################################################################################

export CATALINA_OPTS="-server -Xms256m -Duser.country=US -Djava.library.path=$MPF_HOME/lib"

if [ "$KEYSTORE_PASSWORD" ]
then
    export CATALINA_OPTS="$CATALINA_OPTS -Dtransport.guarantee='CONFIDENTIAL' -Dweb.rest.protocol='https'"
    python << EndOfPythonScript
import xml.etree.ElementTree as ET
import os

class CommentPreservingTreeBuilder(ET.XMLTreeBuilder):
    def __init__(self, *args, **kwargs):
        super(CommentPreservingTreeBuilder, self).__init__(*args, **kwargs)
        self._parser.CommentHandler = self.handle_comment

    def handle_comment(self, data):
        self._target.start(ET.Comment, {})
        self._target.data(data)
        self._target.end(ET.Comment)


keystore_password = os.getenv('KEYSTORE_PASSWORD')
server_xml_path = '/opt/apache-tomcat/conf/server.xml'
tree = ET.parse(server_xml_path, CommentPreservingTreeBuilder())
https_connector = tree.find('./Service/Connector[@sslProtocol="TLS"][@scheme="https"]')

if https_connector is None:
    print 'Enabling HTTPS'
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
    print 'HTTPS already enabled'
EndOfPythonScript
else
    echo 'HTTPS is not enabled'
    export CATALINA_OPTS="$CATALINA_OPTS -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
fi

################################################################################
# Start Tomcat                                                                 #
################################################################################

set +o xtrace

# Wait for mySQL service.
echo "Waiting for MySQL to become available ..."
until mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" -e "quit" >> /dev/null 2>&1; do
  echo "MySQL is unavailable. Sleeping."
  sleep 1
done
echo "MySQL is up"

# Wait for Redis service.
echo "Waiting for Redis to become available ..."
# From https://stackoverflow.com/a/39214806
until [ +PONG = "$( (exec 8<>/dev/tcp/redis/6379 && echo -e 'PING\r\n' >&8 && head -c 5 <&8; exec 8>&-) 2>/dev/null )" ]; do
    echo "Redis is unavailable. Sleeping."
    sleep 1
done
echo "Redis is up"

set -o xtrace

# TODO: Wait for ActiveMQ.

# Run Tomcat (as root user)
/opt/apache-tomcat/bin/catalina.sh run
