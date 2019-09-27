
set -e
set -x

cd /home/mpf/openmpf-docker/br_openmpf

echo '=== OpenMPF Build ==='

export RUN_TESTS=true
#export RUN_TESTS=false

docker build -f openmpf_build/Dockerfile /home/mpf/openmpf-projects --build-arg RUN_TESTS \
  -t br-openmpf-build


echo '=== Workflow Manager ==='
docker build workflow-manager -t br-workflow-manager


echo '=== Node Manager ==='
docker build node-manager -t br-node-manager


echo '=== Integration Tests ==='

docker build integration-tests -t br-integration-tests


echo '=== Python Executor ==='
docker build components -f components/python-executor/Dockerfile -t br-python-executor

echo '=== EAST ==='
docker build /home/mpf/openmpf-projects/openmpf-components/python/EastTextDetection -t br-east-text-detection


echo '=== C++ Component Build ==='
docker build components -f components/cpp-component-build/Dockerfile -t br-cpp-component-build

echo '=== C++ Component Executor ==='
docker build components -f components/cpp-executor/Dockerfile -t br-cpp-executor


echo '=== OcvFace ==='
docker build /home/mpf/openmpf-projects/openmpf-components/cpp/OcvFaceDetection --build-arg RUN_TESTS \
    -t br-ocv-face-detection

echo '=== Tesseract ==='
docker build /home/mpf/openmpf-projects/openmpf-components/cpp/TesseractOCRTextDetection --build-arg RUN_TESTS \
    -t br-tesseract-ocr-detection
