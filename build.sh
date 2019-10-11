set -e
set -x


# docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock \
#    -v /home/mpf/openmpf-docker:/home/mpf/openmpf-docker \
#    -v /home/mpf/openmpf-projects:/home/mpf/openmpf-projects  \
#    -e DOCKER_BUILDKIT=1 \
#    docker /home/mpf/openmpf-docker/build.sh


cd /home/mpf/openmpf-docker


#export RUN_TESTS=${RUN_TESTS:-false}
export RUN_TESTS=${RUN_TESTS:-true}


echo '=== ActiveMQ ==='
docker build activemq -t openmpf_activemq

echo '=== OpenMPF Build ==='
docker build -f openmpf_build/Dockerfile /home/mpf/openmpf-projects --build-arg RUN_TESTS -t openmpf_build

echo '=== C++ Component Build ==='
docker build components -f components/cpp_component_build/Dockerfile -t openmpf_cpp_component_build

echo '=== C++ Component Executor ==='
docker build components -f components/cpp_executor/Dockerfile -t openmpf_cpp_executor

echo '=== Python Executor ==='
docker build components -f components/python_executor/Dockerfile -t openmpf_python_executor

echo '=== Workflow Manager ==='
docker build workflow_manager -t openmpf_workflow_manager

echo '=== Node Manager ==='
docker build node_manager -t openmpf_node_manager


echo '=== Integration Tests ==='
docker build integration_tests -t openmpf_integration_tests


echo '=== OcvFace ==='
docker build /home/mpf/openmpf-projects/openmpf-components/cpp/OcvFaceDetection --build-arg RUN_TESTS \
    -t openmpf_ocv_face_detection


echo '=== Tesseract ==='
docker build /home/mpf/openmpf-projects/openmpf-components/cpp/TesseractOCRTextDetection --build-arg RUN_TESTS \
    -t openmpf_tesseract_ocr_text_detection

echo '=== EAST ==='
docker build /home/mpf/openmpf-projects/openmpf-components/python/EastTextDetection -t openmpf_east_text_detection

