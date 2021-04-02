# syntax=docker/dockerfile:1.2

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2021 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2021 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

FROM centos:7 as openmpf_build

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG en_US.UTF-8

# Disable Python bytecode generation because it was causing build cache issues. It may slightly increase start up
# time, but once everything is imported, there is no difference in performance. If the bytecode files were critical,
# it is unlikely that the official Python Docker images would explicitly delete them. It also saves 86MB of space.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_COMPILE=0


RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/var/cache/yum \
    yum update --assumeyes; \
    yum-config-manager --setopt=skip_missing_names_on_install=False --save; \
    yum-config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64; \
    yum install --assumeyes \
        epel-release \
        https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
        http://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm; \
    CU_VERSION=10-2; \
    yum install --assumeyes --nogpgcheck \
            cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg ffmpeg-devel \
            gtest-devel java-11-openjdk-devel activemq-cpp-devel protobuf-static protobuf-devel \
            libheif-devel file google-noto-emoji-fonts \
            # Python build deps
            openssl-devel libffi-devel \
            # OpenCV build deps
            openblas-devel cuda-minimal-build-$CU_VERSION cuda-cufft-dev-$CU_VERSION cuda-npp-dev-$CU_VERSION \
            libcudnn7-devel-7.6.5.33-1.cuda10.2 libcublas-devel-10.2.2.89 harfbuzz-devel; \
    yum clean all; \
    # For protobuf maven plugin
    ln --symbolic /usr/bin/protoc /usr/local/bin/protoc; \
    ln --symbolic cuda-10.2 /usr/local/cuda; \
    # OpenCV doesn't use the statically compiled CUDA libraries except for libcudart and they are relatively large.
    find /usr/local/cuda/lib64/ -name '*.a' -not -name 'libcudart_static.a' -delete; \
    echo '/usr/local/cuda/lib64' >> /etc/ld.so.conf.d/cuda.conf; \
    ldconfig

ENV JAVA_HOME=/etc/alternatives/java_sdk


RUN --mount=type=tmpfs,target=/tmp \
    mkdir /tmp/python; \
    cd /tmp/python; \
    curl 'https://www.python.org/ftp/python/3.8.2/Python-3.8.2.tar.xz' \
        | tar --extract --xz; \
    cd Python-3.8.2; \
    ./configure --enable-optimizations --with-lto --enable-shared; \
    make --jobs "$(nproc)"; \
    make install; \
    ln --symbolic /usr/local/lib/libpython3.8.so.1.0 /usr/lib64/libpython3.8.so.1.0; \
    rm /usr/local/lib/python3.8/config-3.8-x86_64-linux-gnu/libpython3.8.a; \
    pip3 install --upgrade --no-cache-dir pip; \
    pip3 install --upgrade --no-cache-dir wheel; \
    # find commands taken from official Python Dockerfile
    find /usr/local/lib/python3.8 -depth -type d -a \( -name test -o -name tests -o -name idle_test \) -exec rm -rf '{}' + ; \
    find /usr/local/lib/python3.8 -depth -type f -a \( -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' + ;


RUN --mount=type=tmpfs,target=/tmp \
    mkdir /tmp/opencv-contrib; \
    curl --location 'https://github.com/opencv/opencv_contrib/archive/4.5.0.tar.gz' \
        | tar --extract --gzip --directory /tmp/opencv-contrib; \
    mkdir /tmp/opencv; \
    cd  /tmp/opencv; \
    curl --location 'https://github.com/opencv/opencv/archive/4.5.0.tar.gz' \
        | tar --extract --gzip; \
    cd opencv-4.5.0; \
    mkdir build; \
    cd build; \
    cmake3 -DCMAKE_INSTALL_PREFIX:PATH='/opt/opencv-4.5.0' \
        -DWITH_IPP=false \
        -DBUILD_EXAMPLES=false \
        -DBUILD_TESTS=false \
        -DBUILD_PERF_TESTS=false \
        -DWITH_CUDA=true \
        -DCUDA_ARCH_BIN=3.0 \
        -DCUDA_ARCH_PTX=3.0 \
        -DWITH_CUBLAS=true \
        -DWITH_CUDNN=true \
        -DOPENCV_DNN_CUDA=true \
        -DBUILD_CUDA_STUBS=true \
        -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv-contrib/opencv_contrib-4.5.0/modules \
        ..; \
    make --jobs "$(nproc)" install; \
    ln --symbolic '/opt/opencv-4.5.0/include/opencv4/opencv2' /usr/local/include/opencv2;


RUN --mount=type=tmpfs,target=/tmp \
    mkdir /tmp/pngdefry; \
    cd /tmp/pngdefry; \
    curl --location 'https://github.com/openmpf/pngdefry/archive/v1.2.tar.gz' \
        | tar --extract --gzip; \
    cd pngdefry-1.2; \
    gcc pngdefry.c -o /usr/local/bin/pngdefry;


RUN curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;

COPY . /home/mpf/openmpf-projects

ENV MPF_HOME /home/mpf/openmpf-projects/openmpf/trunk/install

WORKDIR /home/mpf/openmpf-projects/openmpf

RUN --mount=type=cache,id=mvn_cache,target=/root/.m2/repository,sharing=private \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/root/.cache \
    mvn package \
        -DskipTests -Dmaven.test.skip=true -DskipITs \
        -Dcargo.maven.skip=true \
        -Dcomponents.build.components='' \
        -Dstartup.auto.registration.skip=false \
        -Dcomponents.build.parallel.builds="$(nproc)" \
        -Dcomponents.build.make.jobs="$(nproc)"; \
    mkdir --parents /build-artifacts/mvn/mpf; \
    # Move mpf artifacts out of Maven repo so they won't be in the cache mount when another build is started
    mv /root/.m2/repository/org/mitre/mpf /build-artifacts/mvn;

ARG RUN_TESTS=false
RUN \[ "${RUN_TESTS,,}" = true ] || exit 0; \
    # Use nullglob to avoid entering for loop when no glob matches.
    # Use globstar to enable ** globs.
    shopt -s nullglob globstar; \
    for build_root in /root/mpf-component-build /home/mpf/openmpf-projects/openmpf/trunk/build; do \
        cd "$build_root"; \
        for test_executable in **/test/*Test; do \
            cd "$(dirname "$test_executable")"; \
            ./"$(basename "$test_executable")"; \
            cd "$build_root"; \
        done; \
    done;

WORKDIR /build-artifacts

# These two can't be symlinked because Docker was using the build cache even though the files had changed.
# It appears that Docker COPY has an issue when using symlinks with wild cards.
RUN mkdir markup; \
    cp /home/mpf/openmpf-projects/openmpf/trunk/markup/target/*.jar markup/; \
    mkdir java-executor; \
    cp /home/mpf/openmpf-projects/openmpf/trunk/detection/executor/java/target/*.jar java-executor;

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/target/workflow-manager; \
    ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts; \
    ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install; \
    ln --symbolic /root/mpf-sdk-install;

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Build Environment" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-projects" \
      org.label-schema.vendor="MITRE"
