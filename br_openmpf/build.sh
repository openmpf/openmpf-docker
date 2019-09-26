
set -e
set -x

cd /home/mpf/openmpf-docker/br_openmpf

echo '=== OpenMPF Build ==='

docker build -f openmpf_build/Dockerfile /home/mpf/openmpf-projects --build-arg RUN_TESTS=true \
  -t br-openmpf-build --progress plain

#sleep 5

echo '=== Workflow Manager ==='
docker build workflow-manager -t br-workflow-manager


echo '=== Node Manager ==='
docker build node-manager -t br-node-manager


echo '=== Integration Tests ==='

docker build integration-tests -t br-integration-tests


echo '=== Python Executor ==='
docker build components -f components/python-executor/Dockerfile -t br-python-executor
