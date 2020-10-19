# syntax=docker/dockerfile:experimental

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
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

RUN yum update --assumeyes; \
    yum install --assumeyes epel-release https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm; \
    yum install --assumeyes cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg ffmpeg-devel gtest-devel \
            java-11-openjdk-devel activemq-cpp-devel protobuf-static protobuf-devel file \
            # Python build deps
            openssl-devel libffi-devel; \
    yum clean all; \
    rm --recursive /var/cache/yum/*; \
    # For protobuf maven plugin
    ln --symbolic /usr/bin/protoc /usr/local/bin/protoc;

ENV JAVA_HOME=/etc/alternatives/java_sdk

RUN mkdir /tmp/python; \
    cd /tmp/python; \
    curl 'https://www.python.org/ftp/python/3.8.2/Python-3.8.2.tar.xz' \
        | tar --extract --xz; \
    cd Python-3.8.2; \
    ./configure --enable-optimizations --with-lto --enable-shared; \
    make --jobs "$(nproc)"; \
    make install; \
    ln -s /usr/local/lib/libpython3.8.so.1.0 /usr/lib64/libpython3.8.so.1.0; \
    pip3 install --upgrade --no-cache-dir pip; \
    pip3 install --upgrade --no-cache-dir wheel; \
    # find commands taken from official Python Dockerfile
    find /usr/local/lib/python3.8 -depth -type d -a \( -name test -o -name tests -o -name idle_test \) -exec rm -rf '{}' + ; \
    find /usr/local/lib/python3.8 -depth -type f -a \( -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' + ; \
    rm --recursive /tmp/python;


RUN mkdir /tmp/opencv-contrib; \
    cd /tmp/opencv-contrib; \
    curl --location 'https://github.com/opencv/opencv_contrib/archive/3.4.7.tar.gz' \
        | tar --extract --gzip; \
    mkdir /tmp/opencv; \
    cd  /tmp/opencv; \
    curl --location 'https://github.com/opencv/opencv/archive/3.4.7.tar.gz' \
        | tar --extract --gzip; \
    cd opencv-3.4.7; \
    mkdir build; \
    cd build; \
    cmake3 -DCMAKE_INSTALL_PREFIX:PATH="/opt/opencv-3.4.7" -DWITH_IPP=false \
        -DBUILD_EXAMPLES=false -DBUILD_TESTS=false -DBUILD_PERF_TESTS=false \
        -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv-contrib/opencv_contrib-3.4.7/modules ..; \
    make --jobs "$(nproc)" install; \
    ln --symbolic /opt/opencv-3.4.7/include/opencv2 /usr/local/include/opencv2; \
    ln --symbolic /opt/opencv-3.4.7/include/opencv /usr/local/include/opencv; \
    rm --recursive /tmp/opencv /tmp/opencv-contrib;

RUN curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;

COPY . /home/mpf/openmpf-projects

ENV MPF_HOME /home/mpf/openmpf-projects/openmpf/trunk/install

WORKDIR /home/mpf/openmpf-projects/openmpf

RUN --mount=type=cache,id=mvn_cache,target=/root/.m2/repository,sharing=private \
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
