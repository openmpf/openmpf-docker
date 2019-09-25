#!/bin/bash

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


mkdir --parents "$MPF_HOME/share/config"

mpfCustomPropertiesFile="$MPF_HOME/share/config/mpf-custom.properties"

updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.config.enabled" "true"
updateOrAddProperty "$mpfCustomPropertiesFile" "node.auto.unconfig.enabled" "true"


echo 'Waiting for MySQL to become available ...'
/scripts/wait-for-it.sh "$MYSQL_HOST:3306" --timeout=0
echo 'MySQL is available'


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


exec /opt/apache-tomcat/bin/catalina.sh run
