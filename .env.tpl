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

COMPOSE_PROJECT_NAME=openmpf

# Relative path to the "openmpf-projects" repository.
OPENMPF_PROJECTS_PATH=..

# Takes the form: "<registry-host>:<registry-port>/<repository>/", where
# <repository> is usually "openmpf". Make sure to include the "/" at the end.
# Leave blank to use images on the local host or Docker Hub.
REGISTRY=

TAG=latest

WFM_USER=admin
WFM_PASSWORD=mpfadm

ACTIVE_MQ_PROFILE=default

# Set this if using "docker-compose.users.yml".
USER_PROPERTIES_PATH=

# Set these if using "docker-compose.https.yml".
KEYSTORE_PATH=
KEYSTORE_PASSWORD=


# Optional database configuration options.
# Uncomment and modify to customize database configuration.
# JDBC_URL=jdbc:postgresql://db:5432/mpf
# POSTGRES_USER=mpf
# POSTGRES_PASSWORD=password
# POSTGRES_DB=mpf
