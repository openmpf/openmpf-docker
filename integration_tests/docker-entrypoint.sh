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

# If empty, unset MPF_VERSION so that the default value is used by the WFM.
if [ -z "$MPF_VERSION" ]; then
    unset MPF_VERSION
fi

# Remove old test reports since /test-reports gets bind mounted in compose file.
rm --recursive --force /test-reports/*


python3 -u /scripts/descriptor-receiver.py &
descriptor_receiver_pid=$!

cd /home/mpf/openmpf-projects/openmpf

# Move test sample data into a location that's accessible by all of the nodes.
mkdir "$MPF_HOME/share/samples"
cp --recursive trunk/mpf-system-tests/src/test/resources/samples/* "$MPF_HOME/share/samples"
cp --recursive trunk/workflow-manager/src/test/resources/samples/* "$MPF_HOME/share/samples"

if [ -f /scripts/docker-custom-entrypoint.sh ]; then
    source /scripts/docker-custom-entrypoint.sh
fi

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

# Wait for ActiveMQ service.
echo 'Waiting for ActiveMQ to become available ...'
until curl --head "$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1; do
    echo 'ActiveMQ is unavailable. Sleeping.'
    sleep 5
done
echo 'ActiveMQ is up'

set -o xtrace

set +o errexit

mvn verify -Pjenkins \
    -Dcargo.spring.profiles.active=docker,jenkins \
    -Dspring.profiles.active=docker,jenkins \
    -Dit.test=ITWebREST \
    -Dtransport.guarantee=NONE \
    -Dweb.rest.protocol=http \
    -Dstartup.auto.registration.skip=false \
    -Dexec.skip=true \
    -Dnode.manager.disabled=true \
    $MVN_OPTIONS $EXTRA_MVN_OPTIONS # Intentionally unquoted to allow variables to hold mulitple flags.

maven_exit_code=$?

kill "$descriptor_receiver_pid"

cd ../..
mkdir --parents /test-reports/surefire-reports
find . -path '*/surefire-reports/*.xml' -exec cp {} /test-reports/surefire-reports \;

mkdir /test-reports/failsafe-reports
find . -path '*/failsafe-reports/*.xml' -exec cp {} /test-reports/failsafe-reports \;

# This is needed so that the Jenkinsfile can run `git clean` wihout being root at the beginning of the build
chmod -R 777 /test-reports


# Maven doesn't exit with error when tests in certain Maven modules fail.
python3 /scripts/check-test-reports.py /test-reports
check_reports_exit_code=$?

if [ "$maven_exit_code" -ne 0 ]; then
    echo 'DETECTED MAVEN TEST FAILURE(S)'
    exit "$maven_exit_code"
fi

if [ "$check_reports_exit_code" -ne 0 ]; then
    echo 'DETECTED MAVEN TEST FAILURE(S)'
    exit "$check_reports_exit_code"
fi

echo 'DETECTED MAVEN TESTS PASSED'

