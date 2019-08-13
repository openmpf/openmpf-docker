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


ARG BUILD_REGISTRY
ARG BUILD_TAG=latest

FROM centos:7 as extract_tar

WORKDIR /root/install_files

COPY build_artifacts/install.tar.gz .

RUN tar -xf install.tar.gz \
        ./bin/amq_detection_component \
        ./config/Log4cxxConfig.xml \
        './lib/liblog4cxx*' './lib/libactivemq-cpp*' './lib/libQtCore*' './lib/libapr*' './lib/libXext*' \
    && rm install.tar.gz


FROM centos:7

ENV MPF_HOME /opt/mpf

WORKDIR $MPF_HOME

COPY --from=extract_tar /root/install_files/ $MPF_HOME

ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV PYTHONUNBUFFERED 1

ENV BUILD_DIR /home/mpf/component_build

ENV INSTALL_DIR $MPF_HOME/plugins/plugin

COPY docker-executor-entrypoint.py /home/mpf/docker-entrypoint.py

ENTRYPOINT ["python", "/home/mpf/docker-entrypoint.py"]


LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF C++ Component Executor" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE" \
      org.label-schema.version=$BUILD_TAG
