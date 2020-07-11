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

FROM webcenter/activemq

ENV ACTIVE_MQ_PROFILE=default

COPY activemq-*.xml /opt/activemq/conf/
COPY env.* /opt/activemq/bin/

COPY docker-entrypoint.sh /opt/activemq/bin/entrypoint.sh.tmp
# The following tr command deletes the carriage return character '\r', converting CRLF to LF.
RUN tr -d '\r' < /opt/activemq/bin/entrypoint.sh.tmp > /opt/activemq/bin/docker-entrypoint.sh
RUN chmod 755 /opt/activemq/bin/docker-entrypoint.sh

ENTRYPOINT ["/opt/activemq/bin/docker-entrypoint.sh"]

LABEL org.label-schema.build-date="" \
      org.label-schema.license="GPLv2" \
      org.label-schema.name="OpenMPF ActiveMQ" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor="MITRE"
