#!/bin/bash


set -e
set -x

cd /home/mpf/openmpf-docker/openmpf_runtime/python_executor

# After install.tar is rebuilt, the hard link (unlike a symlink) will still be pointing to the previous version of
# install.tar. In other words `rm ../build_artifacts/install.tar` has no effect on ./install.tar
if ! [ "install.tar" -ef "../build_artifacts/install.tar" ]; then
    rm -f install.tar ||:
    # TODO: Find better way to exclude build artifacts other than install.tar (maybe .dockerignore?)
    # The other files in build_artifacts make the "Sending build context to Docker daemon" step take too long.
    # Need to use hard link because Docker doesn't support symlinks outside of build context
    sudo ln ../build_artifacts/install.tar install.tar
fi



# TODO: Use openmpf_runtime as build context
#cd /home/mpf/openmpf-docker/openmpf_runtime
#docker build . -f python_executor/Dockerfile -t openmpf_python_executor


#run_child=1
wfm_docker=1

component_dir=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/examples/PythonOcvComponent/
#component_dir=/home/mpf/python_docker_test/PythonOcvComponent

docker build . -t openmpf_python_executor

if [ "$run_child" ]; then
    echo 'Building child Docker image...'
    docker build -t python_ocv_component "$component_dir"
fi


if [ "$run_child" ] && [ "$wfm_docker" ]; then
    docker run --rm -it \
        --network openmpf_default \
        -v openmpf_shared_data:/opt/mpf/share \
        -e WFM_USER=admin \
        -e WFM_PASSWORD=mpfadm \
        python_ocv_component

elif [ "$run_child" ]; then
    docker run --rm -it \
        --network host \
        -e ACTIVE_MQ_HOST=localhost \
        -e WFM_BASE_URL=http://localhost:8080/workflow-manager \
        -e WFM_USER=admin \
        -e WFM_PASSWORD=mpfadm \
        -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
        python_ocv_component

elif [ "$wfm_docker" ]; then
    docker run --rm -it \
        --network openmpf_default \
        -v openmpf_shared_data:/opt/mpf/share \
        -e WFM_USER=admin \
        -e WFM_PASSWORD=mpfadm \
        -e COMPONENT_LOG_NAME=python-ocv-test.log \
        -v "$component_dir:/home/mpf/component_src" \
        openmpf_python_executor

else
    docker run --rm -it \
        --network host \
        -e ACTIVE_MQ_HOST=localhost \
        -e WFM_BASE_URL=http://localhost:8080/workflow-manager \
        -e WFM_USER=admin \
        -e WFM_PASSWORD=mpfadm \
        -e COMPONENT_LOG_NAME=python-ocv-test.log \
        -v "$component_dir:/home/mpf/component_src" \
        -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
        openmpf_python_executor
fi

