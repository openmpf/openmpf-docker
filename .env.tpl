COMPOSE_PROJECT_NAME=openmpf

# Relative path to the "openmpf-projects" repository.
OPENMPF_PROJECTS_PATH=../openmpf-projects

# Takes the form: "<registry-host>:<registry-port>/<repository>/", where
# <repository> is usually "openmpf". Make sure to include the "/" at the end.
# Leave blank to use images on the local host or Docker Hub.
REGISTRY=

TAG=latest

# MySQL
MYSQL_ROOT_PASSWORD=password
MYSQL_DATABASE=mpf
MYSQL_USER=mpf
MYSQL_PASSWORD=mpf

WFM_USER=admin
WFM_PASSWORD=mpfadm

ACTIVE_MQ_PROFILE=default

# Set these if using "docker-compose.https.yml".
KEYSTORE_PATH=
KEYSTORE_PASSWORD=