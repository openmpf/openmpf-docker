#!/usr/bin/bash

set -o errexit -o pipefail -o xtrace

updateOrAddProperty() {
    file="$1"
    key="$2"
    value="$3"

    if grep --quiet "^$key=" "$file"; then
        sed --in-place "/$key=/s/=.*/=$value/" "$file"
    else
        echo "$key=$value" >> "$file"
    fi
}

# TODO: Add wait to executor entrypoints
# Wait for ActiveMQ service.
echo 'Waiting for ActiveMQ to become available ...'
until curl --head "$ACTIVE_MQ_HOST:8161" >> /dev/null 2>&1; do
    echo 'ActiveMQ is unavailable. Sleeping.'
    sleep 5
done
echo 'ActiveMQ is up'

python -u /scripts/descriptor-receiver.py &
descriptor_receiver_pid=$!

mkdir --parents "$MPF_HOME/share/config"

mpfCustomPropertiesFile="$MPF_HOME/share/config/mpf-custom.properties"

updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.config.enabled" "true"
updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.unconfig.enabled" "true"


cd /home/mpf/openmpf-projects/openmpf

# Move test sample data into a location that's accessible by all of the nodes.
mkdir "$MPF_HOME/share/samples"
cp --recursive trunk/mpf-system-tests/src/test/resources/samples/* "$MPF_HOME/share/samples"
cp --recursive trunk/workflow-manager/src/test/resources/samples/* "$MPF_HOME/share/samples"
cp --recursive trunk/workflow-manager/src/test/resources/samples/* "$MPF_HOME/share/samples"

if [ -f /scripts/docker-custom-entrypoint.sh ]; then
    source /scripts/docker-custom-entrypoint.sh
fi


echo 'Waiting for MySQL to become available ...'
/scripts/wait-for-it.sh "$MYSQL_HOST:3306" --timeout=0
echo 'MySQL is up'


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

set +e

mvn verify \
    -Dspring.profiles.active=jenkins -Pjenkins \
    -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports \
    -DfailIfNoTests=false \
    -Dtransport.guarantee=NONE \
    -Dweb.rest.protocol=http \
    -DgitBranch=test \
    -DgitShortId=123 \
    -DjenkinsBuildNumber=1 \
    -Dstartup.auto.registration.skip=false \
    -Dexec.skip=true \
    $MVN_OPTIONS

mavenRetVal=$?

kill "$descriptor_receiver_pid"

rm --recursive --force /test-reports/*

cd ..
mkdir --parents /test-reports/surefire-reports
find . -path '*/surefire-reports/*.xml' -exec cp {} /test-reports/surefire-reports \;

mkdir /test-reports/failsafe-reports
find . -path '*/failsafe-reports/*.xml' -exec cp {} /test-reports/failsafe-reports \;


# Maven doesn't exit with error when tests in certain Maven modules fail.
python /scripts/check-test-reports.py /test-reports
check_reports_ret_val=$?

if [ "$mavenRetVal" -ne 0 ]; then
    echo 'DETECTED MAVEN TEST FAILURE(S)'
    exit "$mavenRetVal"
fi

if [ "$check_reports_ret_val" -ne 0 ]; then
    echo 'DETECTED MAVEN TEST FAILURE(S)'
    exit "$check_reports_ret_val"
fi

echo 'DETECTED MAVEN TESTS PASSED'

