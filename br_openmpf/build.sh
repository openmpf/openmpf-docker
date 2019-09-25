
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


# docker run --rm -it --network br_openmpf_overlay -v br_openmpf_shared_data:/opt/mpf/share -e WFM_USER=admin -e WFM_PASSWORD=mpfadm fdc72491382923aa47
