# syntax=docker/dockerfile:experimental

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2019 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2019 The MITRE Corporation                                      #
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

# Change config because the centos:7 image sets this yum property to en_US.utf8 which prevents other locales
# (including other Engish locales) from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save; \
    yum install --assumeyes epel-release https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes \
            # OpenMPF dependencies
            cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg ffmpeg-devel \
            java-11-openjdk-devel python-pip python-devel activemq-cpp-devel protobuf-static protobuf-devel \
            gtest-devel \
            # dlib dependencies
            bzip2 \
            # OALPR dependencies
            libjpeg-devel libpng-devel libtiff-devel zlib; \
    yum clean all; \
    rm --recursive --force /var/cache/yum/*; \
    pip install --upgrade --no-cache-dir pip wheel; \
    # For protobuf maven plugin
    ln --symbolic /usr/bin/protoc /usr/local/bin/protoc;

ENV JAVA_HOME=/etc/alternatives/java_sdk


RUN mkdir /tmp/opencv; \
    cd  /tmp/opencv; \
    curl --location 'https://github.com/opencv/opencv/archive/3.4.7.tar.gz' \
        | tar --extract --gzip; \
    cd opencv-3.4.7; \
    mkdir build; \
    cd build; \
    cmake3 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH="/opt/opencv-3.4.7" \
        -DWITH_GSTREAMER:BOOL="0" -DWITH_OPENMP:BOOL="1" \
        -DBUILD_opencv_apps:BOOL="0" -DWITH_OPENCLAMDBLAS:BOOL="0" \
        -DWITH_CUDA:BOOL="0" -DCLAMDFFT_ROOT_DIR:PATH="CLAMDFFT_ROOT_DIR-NOTFOUND" \
        -DBUILD_opencv_aruco:BOOL="0" -DWITH_WEBP:BOOL="0" \
        -DBZIP2_LIBRARIES:FILEPATH="BZIP2_LIBRARIES-NOTFOUND" \
        -DWITH_GIGEAPI:BOOL="0" -DWITH_JPEG:BOOL="1" -DWITH_CUFFT:BOOL="0" \
        -DWITH_IPP:BOOL="0" -DWITH_V4L:BOOL="1" -DWITH_GDAL:BOOL="0" \
        -DWITH_OPENCLAMDFFT:BOOL="0" -DWITH_GPHOTO2:BOOL="0" -DWITH_VTK:BOOL="0" \
        -DWITH_GTK_2_X:BOOL="0" -DBUILD_opencv_world:BOOL="0" -DWITH_TIFF:BOOL="1" \
        -DWITH_1394:BOOL="0" -DWITH_EIGEN:BOOL="0" -DWITH_LIBV4L:BOOL="0" \
        -DBUILD_opencv_ts:BOOL="0" -DWITH_MATLAB:BOOL="0" -DWITH_OPENCL:BOOL="0" \
        -DWITH_PVAPI:BOOL="0" -DENABLE_CXX11:BOOL="1" ..; \
    make --jobs "$(nproc)" install; \
    ln --symbolic /opt/opencv-3.4.7/include/opencv2 /usr/local/include/opencv2; \
    ln --symbolic /opt/opencv-3.4.7/include/opencv /usr/local/include/opencv; \
    rm --recursive /tmp/opencv



RUN curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;



# dlib
RUN mkdir --parents /apps/source/dlib-sources; \
    curl --location 'http://dlib.net/files/dlib-18.18.tar.bz2' \
        | tar --extract --bzip2 --directory /apps/source/dlib-sources;



# Oalpr

RUN mkdir /tmp/leptonica; \
    cd /tmp/leptonica; \
    curl --location 'https://github.com/DanBloomberg/leptonica/archive/1.75.0.tar.gz' \
        | tar --extract --gzip; \
    mkdir leptonica-1.75.0/build; \
    cd leptonica-1.75.0/build; \
    cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..; \
    make install --jobs "$(nproc)"; \
    rm --recursive /tmp/leptonica;


RUN mkdir /tmp/tesseract; \
    cd /tmp/tesseract; \
    curl --location 'https://github.com/tesseract-ocr/tesseract/archive/4.0.0.tar.gz' \
        | tar --extract --gzip; \
    mkdir tesseract-4.0.0/build; \
    cd tesseract-4.0.0/build; \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..; \
    make install --jobs "$(nproc)"; \
    rm --recursive /tmp/tesseract;


RUN mkdir /tmp/oalpr; \
    cd /tmp/oalpr; \
    curl --location 'https://github.com/openalpr/openalpr/archive/6ead2fb8f72ac1929a2e04912c5795af0bf37761.tar.gz' \
        | tar --extract --gzip; \
    cd openalpr-6ead2fb8f72ac1929a2e04912c5795af0bf37761/src; \
    mkdir build; \
    cd build; \
    cmake3 -DCMAKE_CXX_STANDARD=11 -DCMAKE_CXX_STANDARD_REQUIRED=ON -DWITH_DAEMON=OFF \
           -DCMAKE_INSTALL_PREFIX:PATH=/usr/local -DLeptonica_LIB=/usr/local/lib/libleptonica.so ..; \
    make install -j "$(nproc)"; \
    rm --recursive /tmp/oalpr;



COPY . /home/mpf/openmpf-projects

ENV MPF_HOME /home/mpf/openmpf-projects/openmpf/trunk/install

WORKDIR /home/mpf/openmpf-projects/openmpf

ARG RUN_TESTS=false
ARG BUILD_PACKAGE_JSON=/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/openmpf-open-source-package.json

RUN --mount=type=cache,target=/root/.m2/repository,id=mvn_cache \
    # Copy to shell variable so that parameter expansion works
    build_package_json="$BUILD_PACKAGE_JSON"; \
    if [ "${build_package_json:0:1}" != '/' ]; then \
        build_package_json="/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/$build_package_json"; \
    fi; \

    if [ ! -e /root/.m2/repository/edu/cmu/sphinx ]; then \
        tar --extract --file /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz \
            --directory /root/.m2/repository/; \
    fi; \

    cp trunk/workflow-manager/src/main/resources/properties/mpf-private-example.properties \
        trunk/workflow-manager/src/main/resources/properties/mpf-private.properties; \
    mvn package \
        -DskipTests -Dmaven.test.skip=true -DskipITs \
        -Dcargo.maven.skip=true \
        -Dcomponents.build.package.json="$build_package_json" \
        -Dstartup.auto.registration.skip=false \
        -Dcomponents.build.parallel.builds="$(nproc)" \
        -Dcomponents.build.make.jobs="$(nproc)" \
        -DgitBranch='' \
        -DgitShortId='' \
        -DjenkinsBuildNumber=1; \
    # Use nullglob to avoid entering for loop when no glob matches.
    # Use globstar to enable ** globs.
    shopt -s nullglob globstar; \
    if [ "${RUN_TESTS,,}" = true ]; then \
        cd /root/mpf-component-build; \
        for test_executable in **/test/*Test; do \
            cd "$(dirname "$test_executable")"; \
            ./"$(basename "$test_executable")"; \
            cd /root/mpf-component-build; \
        done; \
    fi; \
    mkdir --parents /build-artifacts/plugins; \
    cd /build-artifacts/plugins; \
    # Extract packages here so that child Dockerfiles don't need to use a separate stage just to extract packages.
    for package in /root/mpf-component-build/plugin-packages/*.tar.gz; do \
        tar --extract --file "$package" & \
    done; \
    wait; \
    # Descriptors only
    mkdir /build-artifacts/descriptors; \
    cd /build-artifacts/descriptors; \
    plugins_dir=/build-artifacts/plugins; \
    for full_path in "$plugins_dir"/*/descriptor/descriptor.json; do \
        rel_path="$(realpath --relative-to="$plugins_dir" "$full_path")"; \
        mkdir --parents "$(dirname "$rel_path")"; \
        cp "$full_path" "$rel_path"; \
    done; \
    rm --recursive /root/mpf-component-build;


WORKDIR /build-artifacts

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/target/workflow-manager.war \
                  /build-artifacts/workflow-manager.war; \
    ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install \
                  /build-artifacts/install; \
    ln --symbolic /root/mpf-sdk-install \
                  /build-artifacts/mpf-sdk-install;



LABEL org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Build Environment" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-projects" \
      org.label-schema.vendor="MITRE"
