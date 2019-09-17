# syntax=docker/dockerfile:experimental


ARG BUILD_REGISTRY
ARG BUILD_TAG=latest


FROM centos:7 as openmpf_build

# The centos:7 image sets this yum property to en_US.utf8 which prevents other locales (including other Engish locales)
# from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save


# Remember to change CMakeLists.txt search location (/apps/install) in mpf-protobufs
RUN yum install -y epel-release \
    && yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
                https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && yum install -y \
            # OpenMPF dependencies
            cmake3 make gcc gcc-c++ qt-devel log4cxx-devel boost-devel ffmpeg ffmpeg-devel \
            java-11-openjdk-devel python-pip python-devel activemq-cpp-devel protobuf-static protobuf-devel \
            # dlib dependencies
            bzip2 \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && pip install --upgrade --no-cache-dir pip \
    && pip install --no-cache-dir wheel

# For protobuf maven plugin
RUN ln -s /usr/bin/protoc /usr/local/bin/protoc


ENV JAVA_HOME=/etc/alternatives/java_sdk


RUN mkdir -p /apps/source/opencv_sources \
    && cd /apps/source/opencv_sources \
    && curl --location 'https://github.com/opencv/opencv/archive/3.3.0.tar.gz' \
        | tar --extract --gzip \
    && cd opencv-3.3.0 \
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
    && curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
    | tar --extract --gzip \
    && ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin



# dlib
RUN mkdir -p /apps/source/dlib-sources \
    && cd /apps/source/dlib-sources \
    && curl --location 'http://dlib.net/files/dlib-18.18.tar.bz2' \
        | tar --extract --bzip2


# TesseractOCR

RUN yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm \
    && yum --enablerepo=remi install -y ImageMagick6 ImageMagick6-c++ \
         ImageMagick6-c++-devel ImageMagick6-devel ImageMagick6-libs \
         libgif libjpeg libpng libtiff zlib \
    && yum clean all \
    && rm -rf /var/cache/yum/*

# TesseractOCR and Oalpr

RUN mkdir -p /tmp/leptonica \
    && cd /tmp/leptonica \
    && curl --location 'https://github.com/DanBloomberg/leptonica/archive/1.75.0.tar.gz' \
        | tar --extract --gzip \
    && mkdir -p leptonica-1.75.0/build \
    && cd leptonica-1.75.0/build \
    && cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. \
    && make install -j $(nproc) \
    && rm -rf /tmp/leptonica


RUN mkdir -p /tmp/tesseract \
    && cd /tmp/tesseract \
    && curl --location 'https://github.com/tesseract-ocr/tesseract/archive/4.0.0.tar.gz' \
        | tar --extract --gzip \
    && mkdir -p tesseract-4.0.0/build \
    && cd tesseract-4.0.0/build \
    && PKG_CONFIG_PATH=/usr/local/lib/pkgconfig cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. \
    && make install -j $(nproc) \
    && rm -rf /tmp/tesseract


RUN mkdir -p /tmp/oalpr \
    && cd /tmp/oalpr \
    && curl --location 'https://github.com/openalpr/openalpr/archive/6ead2fb8f72ac1929a2e04912c5795af0bf37761.tar.gz' \
        | tar --extract --gzip \
    && cd openalpr-6ead2fb8f72ac1929a2e04912c5795af0bf37761 \
    && mkdir src/build \
    && cd src/build \
    && cmake3 -DCMAKE_CXX_STANDARD=11 -DCMAKE_CXX_STANDARD_REQUIRED=ON  -DWITH_DAEMON=OFF \
              -DCMAKE_INSTALL_PREFIX:PATH=/usr/local -DLeptonica_LIB=/usr/local/lib/libleptonica.so .. \
    && make install -j "$(nproc)" \
    && ldconfig \
    && rm -r /tmp/oalpr



COPY .  /home/mpf/openmpf-projects



ENV MPF_HOME /home/mpf/openmpf-projects/openmpf/trunk/install

WORKDIR /home/mpf/openmpf-projects/openmpf


# TODO: See if this can be converted to use ARG variable, this strategy is
#    very brittle because it's based on line number:
RUN sed -i '37s/.*/              p:hostName="redis"/' \
    /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/applicationContext-redis.xml

RUN --mount=type=cache,target=/root/.m2/repository,id=mvn_cache \
  if [ ! -e /root/.m2/repository/edu/cmu/sphinx ]; then \
       tar xzf /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz -C /root/.m2/repository/; \
  fi \
  && mvn package \
  -DskipTests -Dmaven.test.skip=true -DskipITs \
  -Dcargo.maven.skip=true \
  -Dcomponents.build.search.paths='/home/mpf/openmpf-projects' \
#  -Dcomponents.build.components='CaffeDetection:OcvFaceDetection:DarknetDetection:SceneChangeDetection:DlibFaceDetection:OalprLicensePlateTextDetection' \
  -Dcomponents.build.components='openmpf-components/java:openmpf-components/cpp:openmpf-contrib-components' \
#  -Dcomponents.build.components='TesseractOCRTextDetection' \
  -Dstartup.auto.registration.skip=false \
  -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build \
  -Dcomponents.build.parallel.builds="$(nproc)" \
  -Dcomponents.build.make.jobs="$(nproc)" \
  -DgitBranch='test' \
  -DgitShortId='123' \
  -DjenkinsBuildNumber=2


WORKDIR /build-artifacts

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/target/workflow-manager \
                  /build-artifacts/workflow-manager
RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install \
                  /build-artifacts/install

# Use nullglob to avoid entering for loop when no matches.
RUN shopt -s nullglob \
    && mkdir -p /build-artifacts/plugins \
    && cd /build-artifacts/plugins \
    && for package in /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages/*.tar.gz; do \
            tar xf "$package" & done && wait



RUN shopt -s nullglob \
    && mkdir -p /build-artifacts/descriptors \
    && cd /build-artifacts/descriptors \
    && plugins_dir=/build-artifacts/plugins \
    && for full_path in "$plugins_dir"/*/descriptor/descriptor.json; do \
            rel_path=$(realpath --relative-to="$plugins_dir" "$full_path") \
            && mkdir -p "$(dirname "$rel_path")" \
            && cp "$full_path" "$rel_path"; \
       done


