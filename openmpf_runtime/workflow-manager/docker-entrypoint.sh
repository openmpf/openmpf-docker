#!/usr/bin/bash

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

set -Ee -o pipefail -o xtrace

################################################################################
# Helper Functions                                                             #
################################################################################

# updateOrAddProperty(1: file, 2: key, 3: value)
updateOrAddProperty() {
  file="$1"
  key="$2"
  value="$3"

  if grep -q "^$key=" "$file"; then
    sed -i "/$key=/s/=.*/=$value/" "$file"
  else
    echo "$key=$value" >> "$file"
  fi
}

################################################################################
# Initial Setup                                                                #
################################################################################

# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*-MPF-MasterNode.list

# NOTE: Docker assigns each Node Manager container a hostname that is a 12-digit
# hash. For each container, we set THIS_MPF_NODE="node-manager_id_<hash>".

# In a swarm deployment, containers are not persisted, so each stack deployment
# results in new Node Manager containers with new hostnames, meaning that we
# cannot meaningfully reuse the previous service configuration.

# Remove nodeManagerConfig.xml so that it can be regenerated.
if grep -q "node-manager_id_*" "$MPF_HOME/share/data/nodeManagerConfig.xml"; then
  rm "$MPF_HOME/share/data/nodeManagerConfig.xml"
fi

# NOTE: We cannot reliably determine which Node Manager logs belong to the
# current deployment, and which belong to the previous deployment due to the
# order in which Docker services are started/restarted. Removing the logs is
# best left to the user.

# NOTE: $HOSTNAME is not known until runtime.
export JGROUPS_TCP_ADDRESS="$HOSTNAME"

markerFile="$MPF_HOME/share/config/.docker-entrypoint-init"

################################################################################
# Configure Properties                                                         #
################################################################################

# Configure properties only if this is the first time we're initializing
# $MPF_HOME/share. This prevents overwriting user customizations made during
# runtime or post-deployment.

if [ ! -f "$markerFile" ]; then
  mkdir -p "$MPF_HOME/share/config"

  mpfCustomPropertiesFile="$MPF_HOME/share/config/mpf-custom.properties"

  updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.config.enabled" "true"
  updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.unconfig.enabled" "true"

  # Update WFM segment size
  updateOrAddProperty "$mpfCustomPropertiesFile" "detection.segment.target.length" "1000"
fi

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
# Create Marker File                                                           #
################################################################################

echo `date` > "$markerFile"

################################################################################
# Start Tomcat                                                                 #
################################################################################

set +o xtrace

# Wait for mySQL service.
echo "Waiting for MySQL to become available ..."
until mysql -h "$MYSQL_HOST" -u root -p"$MYSQL_ROOT_PASSWORD" -e "quit" >> /dev/null 2>&1; do
  echo "MySQL is unavailable. Sleeping."
  sleep 5
done
echo "MySQL is up"

# Wait for Redis service.
echo "Waiting for Redis to become available ..."
# From https://stackoverflow.com/a/39214806
until [ +PONG = "$( (exec 8<>/dev/tcp/redis/6379 && echo -e 'PING\r\n' >&8 && head -c 5 <&8; exec 8>&-) 2>/dev/null )" ]; do
  echo "Redis is unavailable. Sleeping."
  sleep 5
done
echo "Redis is up"

# Wait for ActiveMQ service.
echo "Waiting for ActiveMQ to become available ..."
until curl -I "$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1; do
  echo "ActiveMQ is unavailable. Sleeping."
  sleep 5
done
echo "ActiveMQ is up"

set -o xtrace

# Start streaming logs to logstash
/etc/init.d/filebeat start

# Run Tomcat (as root user)
/opt/apache-tomcat/bin/catalina.sh run
