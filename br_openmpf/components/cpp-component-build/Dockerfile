FROM br-openmpf-build as openmpf-build


FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

# Change config because the centos:7 image sets this yum property to en_US.utf8 which prevents other locales
# (including other Engish locales) from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save; \
    yum install --assumeyes --nogpgcheck epel-release \
            https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg gtest-devel; \
    yum clean all; \
    rm --recursive /var/cache/yum/*;

COPY --from=openmpf-build /opt/opencv-3.3.0 /opt/

# Normally components' CMakeList.txt file includes include(../ComponentSetup.cmake) but since that is outside of the
# components' build context we create it here.
RUN mkdir /home/mpf; echo 'find_package(mpfCMakeHelpers REQUIRED)' > /home/mpf/ComponentSetup.cmake

COPY --from=openmpf-build /build-artifacts/mpf-sdk-install/include /home/mpf/mpf-sdk-install/include
COPY --from=openmpf-build /build-artifacts/mpf-sdk-install/lib /home/mpf/mpf-sdk-install/lib

COPY cpp-component-build/scripts /scripts

ENV PATH /scripts:$PATH

ENV CMAKE_PREFIX_PATH /home/mpf/mpf-sdk-install/lib/cmake

ENV BUILD_DIR /home/mpf/component_build

ENV SRC_DIR /home/mpf/component_src

WORKDIR $SRC_DIR
