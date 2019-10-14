#! /usr/bin/bash

set -x
set -e

cd /home/mpf/openmpf-docker

export RUN_TESTS=true
./build.sh


export COMPOSE_FILE='docker-compose.integration.test.yml:docker-compose.components.yml'

docker-compose up --exit-code-from workflow-manager
docker-compose down -v
