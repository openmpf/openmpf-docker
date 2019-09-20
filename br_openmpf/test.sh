#! /usr/bin/bash

set -e

docker-compose -f docker-compose-test.yml up --exit-code-from workflow-manager
echo exit code: $?
docker-compose -f docker-compose-test.yml down -v

