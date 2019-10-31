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
FROM ${BUILD_REGISTRY}openmpf_build:${BUILD_TAG} as openmpf_build


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes java-11-openjdk-devel ffmpeg; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

ENV JAVA_HOME=/etc/alternatives/java_sdk


RUN curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin;


# It is unclear why the go-offline step doesn't download these also.
RUN mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:get \
    -Dartifact=org.apache.maven.surefire:surefire-junit4:2.12.4

RUN mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:get \
    -Dartifact=org.apache.maven.wagon:wagon-provider-api:1.0-alpha-6


WORKDIR /home/mpf/openmpf-projects/openmpf-java-component-sdk

# Build the SDK in this container instead of copying the .jar from openmpf_build to improve build cacheing
# because the .jar file changes even when the source code does not. This is likely due dates/times appearing the
# .jar file metadata. We also have to copy out parts individually to avoid copying in target directories
# from openmpf_build.
COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf-java-component-sdk/pom.xml pom.xml

COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf-java-component-sdk/detection/java-component-api/pom.xml \
                          detection/java-component-api/pom.xml

COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf-java-component-sdk/detection/audio-video-utils/pom.xml \
                          detection/audio-video-utils/pom.xml

# After downloading all of the dependencies the mvn command fails because it can't find the audio-video-utils .jar.
# This is expected since we are about to build it.
RUN mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:go-offline ||:


COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf-java-component-sdk/detection/java-component-api/src \
                          detection/java-component-api/src

COPY --from=openmpf_build /home/mpf/openmpf-projects/openmpf-java-component-sdk/detection/audio-video-utils/src \
                          detection/audio-video-utils/src

# We don't use a cache mount here since the component developer will likely need most of the libraries downloaded.
RUN mvn install


ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR

LABEL org.label-schema.license="Apache 2.0" \
      org.label-schema.name="OpenMPF Java Component Builder" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf/openmpf-java-component-sdk" \
      org.label-schema.vendor="MITRE"
