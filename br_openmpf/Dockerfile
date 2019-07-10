# syntax=docker/dockerfile:experimental


ARG BUILD_REGISTRY
ARG BUILD_TAG=latest
#FROM ${BUILD_REGISTRY}br_mpf_mvn:${BUILD_TAG} as br_mpf_mvn


FROM centos:7


RUN yum install -y epel-release \
    && yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && yum install -y cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg java-1.8.0-openjdk-devel \
            # Remember to change CMakeLists.txt search location (/apps/install) in mpf-protobufs
            python-pip python-devel activemq-cpp-devel protobuf-static protobuf-devel \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && pip install --upgrade --no-cache-dir pip \
    && pip install --no-cache-dir wheel

# For protobuf maven plugin
RUN ln -s /usr/bin/protoc /usr/local/bin/protoc


ENV JAVA_HOME=/etc/alternatives/java_sdk


RUN mkdir -p /apps/source/opencv_sources \
    && cd /apps/source/opencv_sources \
    && curl -SL 'https://github.com/opencv/opencv/archive/3.3.0-cvsdk.tar.gz' \
        | tar --extract --gzip \
    && cd opencv-3.3.0-cvsdk \
    && mkdir release && cd release && \
    PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" cmake3 \
    -DCMAKE_BUILD_TYPE=Release -DWITH_GSTREAMER:BOOL="0" -DWITH_OPENMP:BOOL="1" \
    -DBUILD_opencv_apps:BOOL="0" -DWITH_OPENCLAMDBLAS:BOOL="0" \
    -DWITH_CUDA:BOOL="0" -DCLAMDFFT_ROOT_DIR:PATH="CLAMDFFT_ROOT_DIR-NOTFOUND" \
    -DBUILD_opencv_aruco:BOOL="0" \
    -DCMAKE_INSTALL_PREFIX:PATH="/apps/install/opencv3.3.0" -DWITH_WEBP:BOOL="0" \
    -DBZIP2_LIBRARIES:FILEPATH="BZIP2_LIBRARIES-NOTFOUND" \
    -DWITH_GIGEAPI:BOOL="0" -DWITH_JPEG:BOOL="1" -DWITH_CUFFT:BOOL="0" \
    -DWITH_IPP:BOOL="0" -DWITH_V4L:BOOL="1" -DWITH_GDAL:BOOL="0" \
    -DWITH_OPENCLAMDFFT:BOOL="0" -DWITH_GPHOTO2:BOOL="0" -DWITH_VTK:BOOL="0" \
    -DWITH_GTK_2_X:BOOL="0" -DBUILD_opencv_world:BOOL="0" -DWITH_TIFF:BOOL="1" \
    -DWITH_1394:BOOL="0" -DWITH_EIGEN:BOOL="0" -DWITH_LIBV4L:BOOL="0" \
    -DBUILD_opencv_ts:BOOL="0" -DWITH_MATLAB:BOOL="0" -DWITH_OPENCL:BOOL="0" \
    -DWITH_PVAPI:BOOL="0" -DENABLE_CXX11:BOOL="1" .. && \
    make -j$(nproc) && make install && \
    sh -c 'echo "/apps/install/opencv3.3.0/lib" >> /etc/ld.so.conf.d/mpf-x86_64.conf' && \
    ln -sf /apps/install/opencv3.3.0 /opt/opencv-3.3.0 && \
    ln -sf /apps/install/opencv3.3.0/include/opencv2 /usr/local/include/opencv2 && \
    ln -sf /apps/install/opencv3.3.0/include/opencv /usr/local/include/opencv && \
    ldconfig && export OpenCV_DIR=/opt/opencv-3.3.0/share/OpenCV \
    && cd / && rm -rf /apps/source/opencv_sources



RUN cd /opt \
    && curl -SL 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
    | tar --extract --gzip \
    && ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin

#COPY --from=br_mpf_mvn /root/.m2 /root/.m2


WORKDIR /home/mpf/openmpf-projects


COPY openmpf /home/mpf/openmpf-projects/openmpf

COPY openmpf-build-tools /home/mpf/openmpf-projects/openmpf-build-tools

COPY openmpf-cpp-component-sdk  /home/mpf/openmpf-projects/openmpf-cpp-component-sdk

COPY openmpf-python-component-sdk  /home/mpf/openmpf-projects/openmpf-python-component-sdk

COPY openmpf-java-component-sdk  /home/mpf/openmpf-projects/openmpf-java-component-sdk



WORKDIR /home/mpf/openmpf-projects/openmpf

ENV LD_LIBRARY_PATH=/apps/install/lib

RUN --mount=type=cache,target=/root/.m2 mvn install \
  -DskipTests -Dmaven.test.skip=true -DskipITs \
  -Dmaven.tomcat.skip=true \
  -Dcomponents.build.components="" \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -Dcomponents.build.parallel.builds="$(nproc)" \
  -Dcomponents.build.make.jobs="$(nproc)" \
  -DgitBranch='test' \
  -DgitShortId='123' \
  -DjenkinsBuildNumber=1
