# syntax=docker/dockerfile:experimental

FROM br-openmpf-build as openmpf-build


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

RUN yum install --assumeyes https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes ffmpeg; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

ENV MPF_HOME /opt/mpf

WORKDIR $MPF_HOME

# Use mount and cp shell command because docker COPY resolves symlinks which will end up duplicate copies the libraries.
RUN --mount=type=bind,from=openmpf-build,source=/build-artifacts/install/lib,target=/tmp/mpf-libs \
    cd /tmp/mpf-libs; \
    # component executor binary's dependencies
    cp --preserve=links --no-dereference liblog4cxx* libactivemq-cpp* libQtCore* libapr* libXext* \
        /usr/lib64;

# component executor binary
COPY --from=openmpf-build /build-artifacts/install/bin/amq_detection_component $MPF_HOME/bin/amq_detection_component

# component executor log config
COPY --from=openmpf-build /build-artifacts/install/config/Log4cxxConfig.xml $MPF_HOME/config/


ENV MPF_LOG_PATH $MPF_HOME/share/logs

ENV PYTHONUNBUFFERED 1

ENV BUILD_DIR /home/mpf/component_build

ENV INSTALL_DIR $MPF_HOME/plugins/plugin

COPY docker-executor-entrypoint.py /scripts/docker-entrypoint.py

ENTRYPOINT ["python", "/scripts/docker-entrypoint.py"]
