#! /usr/bin/bash

set -x
set -e

export RUN_TESTS=true
./build.sh

docker-compose -f docker-compose-test.yml up --exit-code-from workflow-manager
echo exit code: $?
docker-compose -f docker-compose-test.yml down -v




#docker-compose -f docker-compose-test.yml run workflow-manager
#echo "exit code: $?"
#docker-compose -f docker-compose-test.yml down -v


