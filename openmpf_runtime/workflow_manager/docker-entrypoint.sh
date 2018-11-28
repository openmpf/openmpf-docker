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

# Cleanup
rm -f $MPF_HOME/share/nodes/MPF_Channel/*-MPF-MasterNode.list

# Setup
# NOTE: $HOSTNAME is not known until runtime.
export JGROUPS_TCP_ADDRESS="$HOSTNAME"

# Configure
echo 'node.auto.config.enabled=true' >> $MPF_HOME/config/mpf-custom.properties
echo 'node.auto.unconfig.enabled=true' >> $MPF_HOME/config/mpf-custom.properties

# Update WFM segment size
echo 'detection.segment.target.length=1000' >> $MPF_HOME/config/mpf-custom.properties

# Wait for mySQL service.
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
    ssl_connector_attrs = dict(
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
    ET.SubElement(tree.find('Service'), 'Connector', ssl_connector_attrs)
    tree.write(server_xml_path)
else:
    print 'HTTPS already enabled'
EndOfPythonScript
else
    echo 'HTTPS is not enabled'
    export CATALINA_OPTS="$CATALINA_OPTS -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
fi

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
