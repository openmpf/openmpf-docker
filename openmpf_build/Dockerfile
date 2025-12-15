# syntax=docker/dockerfile:1.20

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2024 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2024 The MITRE Corporation                                      #
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

FROM ubuntu:24.04 AS apt_install

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Disable Python bytecode generation because it was causing build cache issues. It may slightly
# increase start up time, but once everything is imported, there is no difference in performance.
# If the bytecode files were critical, it is unlikely that the official Python Docker images would
# explicitly delete them.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_COMPILE=0

RUN --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt/lists  \
    --mount=type=tmpfs,target=/tmp <<eot
    apt-get update
    apt-get upgrade -y
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        wget ca-certificates gnupg2 unzip cmake make g++ file \
        libssl-dev libgtest-dev liblog4cxx-dev libboost-dev \
        openjdk-25-jdk-headless python3.12-dev python3.12-venv libgl1 \
        libopenblas-dev liblapacke-dev libavcodec-dev libavcodec-extra libavformat-dev  \
        libavutil-dev libswscale-dev libharfbuzz-dev libfreetype-dev \
        libde265-dev git nasm ninja-build pkg-config

    # Cannot set up cuda repo at the beginning because it requires wget ca-certificates gnupg2
    wget -O- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub \
        | apt-key add -
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /" \
        > /etc/apt/sources.list.d/cuda.list
    apt-get update
    apt-get install -y --no-install-recommends cuda-minimal-build-13-1 libcufft-dev-13-1 \
        libnpp-dev-13-1 libcublas-dev-13-1 libcudnn9-dev-cuda-13

    # OpenCV does not use the statically compiled CUDA libraries except for libcudart and they are relatively large.
    find /usr/local/cuda/lib64/ -name '*.a' -not -name libcudart_static.a -delete
    ln --symbolic /usr/include/x86_64-linux-gnu/openblas-pthread/cblas.h /usr/include/cblas.h
    ln --symbolic /usr/bin/cmake /usr/bin/cmake3
eot


FROM apt_install AS ocv_install

# TODO: Use a tagged version of OpenCV after CUDA 13 support is included.
# OpenCV 4.12 does not work with CUDA 13. A PR to fix that has recently landed to the OpenCV repo,
# but it has not been included in a release yet.
# https://github.com/opencv/opencv/pull/27636
ARG OPENCV_VERSION=1d5bf7a09c3f189d3f7114da3e3b615b6f285ca0
ARG OPENCV_CONTRIB_VERSION=5ed0a377b6ad6abf545770384e632ff35eebad64

RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/opencv-contrib
    wget -O- "https://github.com/opencv/opencv_contrib/archive/${OPENCV_CONTRIB_VERSION}.tar.gz" \
        | tar --extract --gzip --directory /tmp/opencv-contrib
    mkdir /tmp/opencv
    cd /tmp/opencv
    wget -O- "https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz" \
        | tar --extract --gzip
    cd "opencv-${OPENCV_VERSION}"
    mkdir build
    cd build

    cmake -DCMAKE_INSTALL_PREFIX:PATH=/opt/opencv-4.13.0 \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_IPP=false \
        -DBUILD_EXAMPLES=false \
        -DBUILD_TESTS=false \
        -DBUILD_PERF_TESTS=false \
        -DWITH_CUDA=true \
        -DCUDA_ARCH_BIN=8.0 \
        -DCUDA_ARCH_PTX=8.0 \
        -DWITH_CUBLAS=true \
        -DWITH_CUDNN=true \
        -DOPENCV_DNN_CUDA=true \
        -DBUILD_CUDA_STUBS=true \
        -DOPENCV_EXTRA_MODULES_PATH="/tmp/opencv-contrib/opencv_contrib-${OPENCV_CONTRIB_VERSION}/modules" \
        ..
    make --jobs "$(nproc)" install/strip
    ln --symbolic /opt/opencv-4.13.0/include/opencv4/opencv2 /usr/local/include/opencv2
eot


FROM apt_install

RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/abseil
    wget -O- https://github.com/abseil/abseil-cpp/releases/download/20240722.0/abseil-cpp-20240722.0.tar.gz \
        | tar --extract --gzip --directory /tmp/abseil;

    mkdir /tmp/protobuf
    cd /tmp/protobuf
    wget -O- https://github.com/protocolbuffers/protobuf/releases/download/v28.3/protobuf-28.3.tar.gz \
        | tar --extract --gzip;

    cd protobuf-28.3
    mkdir build
    cd build
    cmake \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DABSL_ROOT_DIR=/tmp/abseil/abseil-cpp-20240722.0 \
        -Dprotobuf_BUILD_TESTS=OFF \
        ..
    cmake --build . --parallel "$(nproc)"
    cmake --install . --strip
eot


RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/activemq-cpp
    cd /tmp/activemq-cpp
    wget -O- https://dlcdn.apache.org/activemq/activemq-cpp/3.9.5/activemq-cpp-library-3.9.5-src.tar.gz \
        | tar --extract --gzip
    cd activemq-cpp-library-3.9.5
    ./configure
    make --jobs "$(nproc)" install-strip
eot


RUN wget -O- https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.0-latest-linux64-gpl-8.0.tar.xz \
        | tar --extract --xz --directory /usr/local/bin --strip-components 2 --wildcards \
            '*'/bin/{ffmpeg,ffprobe}


# Markup uses the emoji font for icons.
RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/noto
    cd /tmp/noto
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoEmoji-unhinted.zip
    unzip NotoEmoji-unhinted.zip
    mkdir --parents /usr/share/fonts/google-noto-emoji
    cp NotoEmoji-Regular.ttf /usr/share/fonts/google-noto-emoji
eot


RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/pngdefry
    cd /tmp/pngdefry
    wget -O- https://github.com/openmpf/pngdefry/archive/v1.2.tar.gz | tar --extract --gzip
    cd pngdefry-1.2
    gcc pngdefry.c -o /usr/local/bin/pngdefry
eot


RUN wget -O- https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;


RUN --mount=type=tmpfs,target=/tmp <<eot
    mkdir /tmp/libheif
    cd /tmp/libheif
    wget -O- https://github.com/strukturag/libheif/archive/refs/tags/v1.20.2.tar.gz \
        | tar --extract --gzip
    cd libheif-1.20.2/third-party
    bash aom.cmd
    cd ..
    mkdir build
    cd build
    PKG_CONFIG_PATH=/tmp/libheif/libheif-1.20.2/third-party/aom/dist/lib/pkgconfig cmake \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DWITH_EXAMPLES=false \
        -DWITH_AOM_DECODER=true \
        -DENABLE_PLUGIN_LOADING=false \
        -DCMAKE_BUILD_TYPE=Release ..
    make --jobs "$(nproc)" install/strip
    cp heifio/libheifio.a /usr/lib64
    mkdir -p /usr/include/libheif/heifio
    cp ../heifio/*.h /usr/include/libheif/heifio
eot

COPY --from=ocv_install /opt/opencv-4.13.0 /opt/opencv-4.13.0

RUN ln --symbolic /opt/opencv-4.13.0/include/opencv4/opencv2 /usr/local/include/opencv2

COPY . /home/mpf/openmpf-projects

ENV MPF_HOME=/home/mpf/openmpf-projects/openmpf/trunk/install

WORKDIR /home/mpf/openmpf-projects/openmpf


RUN --mount=type=cache,id=mvn_cache,target=/root/.m2/repository,sharing=private \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/root/.cache \
    mvn package \
        -DskipTests -Dmaven.test.skip=true -DskipITs \
        -Dcomponents.build.components='' \
        -Dstartup.auto.registration.skip=false \
        -Dcomponents.build.parallel.builds="$(nproc)" \
        -Dcomponents.build.make.jobs="$(nproc)"; \
    mkdir --parents /build-artifacts/mvn/mpf; \
    # Move mpf artifacts out of Maven repo so they won't be in the cache mount when another build is started
    mv /root/.m2/repository/org/mitre/mpf /build-artifacts/mvn;


ARG RUN_TESTS=false
RUN <<eot
    if [ "${RUN_TESTS,,}" = true ]; then
        LD_LIBRARY_PATH="$MPF_HOME/lib:$LD_LIBRARY_PATH" find \
            /root/mpf-component-build /home/mpf/openmpf-projects/openmpf/trunk/build \
            -wholename '**/test/*Test' -execdir '{}' \;
    fi
eot

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

RUN cp -r /home/mpf/openmpf-projects/openmpf-docker/openmpf_build/scripts /scripts;

LABEL org.label-schema.build-date="" \
      org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Build Environment" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-projects" \
      org.label-schema.vendor="MITRE"
