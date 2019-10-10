#! /usr/bin/bash

set -x
set -e

export RUN_TESTS=true
./build.sh

docker-compose -f docker-compose.integration.test.yml up --exit-code-from workflow-manager
docker-compose -f docker-compose.integration.test.yml down -v

