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


# Extract tar in separate container to avoid bloat in final image since we only need some of the files.
FROM centos:7 as extract_tar

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

RUN yum install -y epel-release \
    # libSM and libXrender packages are required for opencv-python
    && yum install -y python-pip libSM libXrender \
    && yum clean all \
    && rm -rf /var/cache/yum/*

# Virtualenv must be in exact same directory as in the final image because virtualenvs are not relocatable.
RUN pip install --no-cache-dir --upgrade pip virtualenv \
    && virtualenv "$COMPONENT_VIRTUALENV"

WORKDIR /root/install_files
COPY build_artifacts/install.tar .

RUN tar -xf install.tar \
        # Python component SDK wheels
        ./python/wheelhouse \
        # Component executor binary
        ./bin/amq_detection_component \
        # Component executor log config
        ./config/Log4cxxConfig.xml \
        # Libraries required for component executor
        './lib/liblog4cxx*' './lib/libactivemq-cpp*' './lib/libQtCore*' './lib/libapr*' './lib/libXext*' \
    && rm install.tar \
    # Install MPF .whl files here so that only the expanded contents of the whl file are present in final image.
    && "$COMPONENT_VIRTUALENV/bin/pip" --no-cache-dir install python/wheelhouse/* \
    && rm -rf python


# Docker COPY only preserves symlinks when copying an entire directory so we copy the files and their symlinks in to
# a temporary directory.
RUN mkdir /root/copy_libs64 \
    && cd /usr/lib64 \
    && cp --preserve=links --no-dereference libSM.so* libICE.so* libXrender.so* libX11* libxcb.so* libXau.so* \
            /root/copy_libs64



FROM centos:7

# Copy in opencv-python dependencies
COPY --from=extract_tar /root/copy_libs64 /usr/lib64/

ENV MPF_HOME /opt/mpf
ENV COMPONENT_VIRTUALENV $MPF_HOME/plugins/plugin/venv

WORKDIR $MPF_HOME
COPY --from=extract_tar /root/install_files/ $MPF_HOME
COPY --from=extract_tar $COMPONENT_VIRTUALENV $COMPONENT_VIRTUALENV

ENV MPF_LOG_PATH $MPF_HOME/share/logs

# print()'ed messsages from docker-entrypoint.py were not being shown at the right time.
# Only applies to stdin, stdout and stderr
ENV PYTHONUNBUFFERED 1

COPY python_executor/scripts /home/mpf/scripts
COPY python_executor/docker-entrypoint.py /home/mpf/

# Command used when this Dockerfile is extended by component's Dockerfile
ONBUILD ENTRYPOINT ["python", "/home/mpf/docker-entrypoint.py"]

# Command used when this Dockerfile is not extended. Source code must be bind-mounted to /home/mpf/component_src
ENTRYPOINT ["bash", "-c", "/home/mpf/scripts/install-component.sh && python /home/mpf/docker-entrypoint.py"]



################################################################################
# Labels                                                                       #
################################################################################

ARG BUILD_TAG
ARG BUILD_DATE
ARG BUILD_SHAS

# Clear inherited labels from CentOS 7.4.1708 base image.
# TODO: Remove these when we start using a newer CentOS base image.
LABEL build-date= \
      license= \
      name= \
      vendor=

# Set labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Python Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE" \
      org.label-schema.version=$BUILD_TAG
