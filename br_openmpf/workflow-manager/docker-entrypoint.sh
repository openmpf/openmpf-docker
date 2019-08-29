#!/bin/bash

set -e
set -x

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



/opt/apache-tomcat/bin/catalina.sh run
