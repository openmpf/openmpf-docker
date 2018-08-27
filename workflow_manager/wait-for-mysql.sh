#!/bin/bash
# wait-for-mysql.sh

set -e

host="$1"
shift
cmd="$@"

until mysql -h $MYSQL_HOST -u root -ppassword -e"quit"; do
  >&2 echo "MySQL is unavailable - sleeping"
  sleep 1
done

>&2 echo "MySQL is up - executing command"
exec $cmd
