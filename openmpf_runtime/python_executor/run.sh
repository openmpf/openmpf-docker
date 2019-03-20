#!/bin/bash


set -e
set -x

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
#docker build . -f python_executor/Dockerfile -t python_executor

run_child=1

cd /home/mpf/openmpf-docker/openmpf_runtime/python_executor
docker build . -t python_executor

if [ "$run_child" ]; then
    echo ===========
    /home/mpf/python_docker_test/PythonOcvComponent/run.sh
else
    component_dir=/home/mpf/openmpf-projects/openmpf-python-component-sdk/detection/examples/PythonOcvComponent/
    docker run --rm -it \
        --network host \
        -e ACTIVE_MQ_HOST=localhost \
        -e WFM_BASE_URL=http://localhost:8080/workflow-manager \
        -v "$component_dir:/home/mpf/component_src" \
        -v "$MPF_HOME/share/remote-media:$MPF_HOME/share/remote-media" \
        python_executor
fi

