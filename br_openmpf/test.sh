#! /usr/bin/bash

set -e

docker-compose -f docker-compose-test.yml up
docker-compose -f docker-compose-test.yml down -v

