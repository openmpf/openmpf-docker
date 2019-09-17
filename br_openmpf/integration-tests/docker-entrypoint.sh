#!/usr/bin/bash

set -Ee -o pipefail -o xtrace



#set +o xtrace
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

#set -o xtrace

cd /home/mpf/openmpf-projects/openmpf


mvn verify \
  -Dspring.profiles.active=jenkins -Pjenkins \
  -Dit.test=ITComponentLifecycle,ITWebREST,ITComponentRegistration,ITWebStreamingReports \
  -DfailIfNoTests=false \
  -Dtransport.guarantee="NONE" -Dweb.rest.protocol="http" \
  -DgitBranch='test' \
  -DgitShortId='123' \
  -DjenkinsBuildNumber=1 \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.parallel.builds="$(nproc)" \
  -Dcomponents.build.make.jobs="$(nproc)" \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -Dcomponents.build.search.paths='/home/mpf/openmpf-projects' \
  -Dcomponents.build.components='openmpf-components/cpp/OcvFaceDetection'
#  -Dcomponents.build.components='openmpf-components/java:openmpf-components/cpp:openmpf-contrib-components'


