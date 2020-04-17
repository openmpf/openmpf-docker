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

FROM webcenter/activemq

# TODO: This approach to using sed is brittle:
RUN sed -i '27s/.*/# ACTIVEMQ_OPTS_MEMORY="-Xms64M -Xmx1G"/' /opt/activemq/bin/env

COPY activemq.xml /opt/activemq/conf/

# TODO: This approach to using sed is brittle:
RUN sed -i '52s/.*/log4j.appender.logfile.layout.ConversionPattern=%d %p [%t] %c - %m%n/' /opt/activemq/conf/log4j.properties

################################################################################
# Labels                                                                       #
################################################################################

ARG BUILD_TAG
ARG BUILD_DATE
ARG BUILD_SHAS

# Set labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="GPLv2" \
      org.label-schema.name="OpenMPF ActiveMQ" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE" \
      org.label-schema.version=$BUILD_TAG