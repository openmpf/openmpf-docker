#!/usr/bin/bash

set -Ee -o pipefail -o xtrace

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
mkdir -p "$MPF_HOME/share/config"

mpfCustomPropertiesFile="$MPF_HOME/share/config/mpf-custom.properties"

updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.config.enabled" "true"
updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.unconfig.enabled" "true"


cd /home/mpf/openmpf-projects/openmpf

# Move test sample data into a location that's accessible by all of the nodes.
mkdir -p "$MPF_HOME/share/samples"
cp -r trunk/mpf-system-tests/src/test/resources/samples/* "$MPF_HOME/share/samples"
cp -r trunk/workflow-manager/src/test/resources/samples/* "$MPF_HOME/share/samples"


set +o xtrace
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



set +e

mvn verify \
    -Dspring.profiles.active=jenkins -Pjenkins \
    -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports \
    -DfailIfNoTests=false \
    -Dtransport.guarantee="NONE" -Dweb.rest.protocol="http" \
    -DgitBranch='test' \
    -DgitShortId='123' \
    -DjenkinsBuildNumber=1 \
    -Dstartup.auto.registration.skip=false \
    -Dexec.skip=true
#    -Dcomponents.build.parallel.builds="$(nproc)" \
#    -Dcomponents.build.make.jobs="$(nproc)" \
#    -Dcomponents.build.components='' \
#    -Dcomponents.build.sdks.java='' \
#    -Dcomponents.build.sdks.python='' \
#    -Dcomponents.build.sdks.cpp=''

#    -Dcomponents.build.search.paths='/home/mpf/openmpf-projects' \
#    -Dcomponents.build.components='openmpf-components/cpp/OcvFaceDetection' \
#    -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build
#  -Dcomponents.build.components='openmpf-components/java:openmpf-components/cpp:openmpf-contrib-components'

mavenRetVal=$?


mkdir -p /test-reports/surefire-reports
find . -path '*/surefire-reports/*.xml' -exec cp {} /test-reports/surefire-reports \;

mkdir -p /test-reports/failsafe-reports
find . -path '*/failsafe-reports/*.xml' -exec cp {} /test-reports/failsafe-reports \;


if [ "$mavenRetVal" -eq 0 ]; then
  echo 'DETECTED MAVEN TESTS PASSED'
else
  echo 'DETECTED MAVEN TEST FAILURE(S)'
fi

exit "$mavenRetVal"

