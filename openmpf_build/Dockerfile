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

FROM centos:7.4.1708 as openmpf_build
WORKDIR /home/mpf

# TODO: "&&" remove source code after building libs.

################################################################################
# Initial Setup                                                                #
################################################################################

# Create the "mpf" user:
RUN useradd -u 376 -U -d /home/mpf -ms /bin/bash -G wheel -p mpf mpf

# Set up yum repo:
RUN yum install -y epel-release deltarpm && yum clean all
RUN yum update -y && yum clean all

ENV MPF_HOME=/home/mpf/openmpf-projects/openmpf/trunk/install

# Create directories for sources:
RUN mkdir -p /apps/install/lib && mkdir -p /apps/bin/apache && \
    mkdir -p /apps/source/cmake_sources && \
    mkdir /apps/source/apache_sources && mkdir /apps/source/google_sources && \
    mkdir /apps/source/opencv_sources && mkdir /apps/source/ffmpeg_sources && \
    mkdir /apps/source/dlib-sources && mkdir /apps/source/openalpr_sources && \
    mkdir /apps/source/tesseract_sources && \
    chown -R mpf /apps && chmod -R 755 /apps

# Create the OpenMPF ldconfig file:
# Add /apps/install/lib to the OpenMPF ldconfig file:
# Update the shared library cache:
RUN touch /etc/ld.so.conf.d/mpf-x86_64.conf && \
    sh -c 'echo "/apps/install/lib" >> /etc/ld.so.conf.d/mpf-x86_64.conf' && \
    ldconfig

# Install build tools:
RUN yum install -y git python-pip python-devel python-setuptools file \
    python-setuptools-devel gcc gcc-c++ make autoconf automake \
    libtool yasm nasm bzip2 cmake3 numpy perl-File-Find-Rule which \
    libffi-devel openssl-devel apr apr-util apr-util-ldap log4cxx \
    log4cxx-devel qt qt-devel qt-x11 boost boost-devel wget dos2unix && \
    yum clean all && rm -rf /var/cache/yum/*

# Install Python dependencies:
RUN pip install --upgrade pip && pip install --upgrade setuptools && \
    pip install wheel virtualenv

# Install C Foreign Function Interface (CFFI):
RUN cd /home/mpf && easy_install -U cffi

################################################################################
# Install OpenJDK                                                              #
################################################################################

# Install OpenJDK:
RUN yum -y install java-1.8.0-openjdk && \
# /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.212.b04-0.el7_6.x86_64/bin/java
    alternatives --install /usr/bin/java java /usr/java/jdk*/jre/bin/java 20000 && \
    alternatives --install /usr/bin/jar jar /usr/java/jdk*/bin/jar 20000 && \
    alternatives --install /usr/bin/javac javac /usr/java/jdk*/bin/javac 20000 && \
    alternatives --install /usr/bin/javaws javaws /usr/java/jdk*/jre/bin/javaws 20000 && \
    alternatives --set java /usr/java/jdk*/jre/bin/java && \
    alternatives --set javaws /usr/java/jdk*/jre/bin/javaws && \
    alternatives --set javac /usr/java/jdk*/bin/javac && \
    alternatives --set jar /usr/java/jdk*/bin/jar; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk*/bin/jar 20000 && \
    alternatives --set jar /usr/java/jdk*/bin/jar

# TODO: Pipe all tars into extract command:
#  wget -qO- your_link_here | tar xvz -C /target/directory

################################################################################
# Install Apache Tomcat                                                        #
################################################################################

# Apache Tomcat 7.0.72:
RUN wget -nv -O /apps/bin/apache/apache-tomcat-7.0.72.tar.gz \
    "http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.72/bin/apache-tomcat-7.0.72.tar.gz" && \
    cd /apps/bin/apache && tar xzf apache-tomcat-7.0.72.tar.gz && \
    mkdir -p /usr/share/apache-tomcat && \
    cp -Rf /apps/bin/apache/apache-tomcat-7.0.72/* /usr/share/apache-tomcat/ && \
    chown -R mpf /usr/share/apache-tomcat && chmod -R 755 /usr/share/apache-tomcat && \
    ln -s /usr/share/apache-tomcat /opt/apache-tomcat && \
    perl -i -p0e 's/<!--\n    <Manager pathname="" \/>\n      -->.*?/<!-- -->\n    <Manager pathname="" \/>/s' \
        /opt/apache-tomcat/conf/context.xml && \
    rm -rf /opt/apache-tomcat/webapps/*

################################################################################
# Install Apache Maven                                                         #
################################################################################

# Apache Maven 3.3.3:
RUN wget -nv -O /apps/bin/apache/apache-maven-3.3.3-bin.tar.gz \
    "https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz" && \
    cd /apps/bin/apache && tar xzf apache-maven-3.3.3-bin.tar.gz && \
    mkdir /opt/apache-maven && cp -Rf /apps/bin/apache/apache-maven-3.3.3/* /opt/apache-maven/ && \
    chown -R mpf /opt/apache-maven && \
    alternatives --install "/usr/bin/mvn" "mvn" "/opt/apache-maven/bin/mvn" 0 && \
    alternatives --set mvn /opt/apache-maven/bin/mvn

################################################################################
# Install CMake                                                                #
################################################################################

# cmake 2.8.12.2:
RUN wget -nv -O /apps/source/cmake_sources/cmake-2.8.12.2.tar.gz \
    "https://cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz" && \
    cd /apps/source/cmake_sources && tar xzf cmake-2.8.12.2.tar.gz && \
    cd cmake-2.8.12.2 && chmod +x * && ./configure --prefix=/apps/install && make -j && \
    make install && ldconfig && ln -s /apps/install/bin/cmake /usr/local/bin/cmake

################################################################################
# Build Audio and Video Codecs and FFmpeg                                      #
################################################################################

# TODO: FFmpeg comes with many decoders by default. It may not be necessary to
#    build all or any of these encoders if we only need decoding functionality.

# opencore-amr:
RUN wget -nv -O /apps/source/ffmpeg_sources/opencore-amr-0.1.4.tar.gz \
    "https://downloads.sf.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.4.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf opencore-amr-0.1.4.tar.gz && \
    cd opencore-amr-0.1.4 && autoreconf -fiv && \
    ./configure --prefix="/apps/install" --enable-shared && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libfdk_aac:
RUN wget -nv -O /apps/source/ffmpeg_sources/fdk-aac-0.1.5.tar.gz \
    "https://github.com/mstorsjo/fdk-aac/archive/v0.1.5.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf fdk-aac-0.1.5.tar.gz && \
    cd fdk-aac-0.1.5 && autoreconf -fiv && ./configure --prefix="/apps/install" --enable-shared && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libmp3lame:
RUN wget -nv -O /apps/source/ffmpeg_sources/lame-3.99.5.tar.gz \
    "http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf lame-3.99.5.tar.gz && cd lame-3.99.5 && \
    ./configure --prefix="/apps/install" --bindir="/apps/install/bin" --enable-shared --enable-nasm && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libogg:
RUN wget -nv -O /apps/source/ffmpeg_sources/libogg-1.3.2.tar.gz \
    "http://downloads.xiph.org/releases/ogg/libogg-1.3.2.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf libogg-1.3.2.tar.gz && \
    cd libogg-1.3.2 && ./configure --prefix="/apps/install" --enable-shared && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libopus:
RUN wget -nv -O /apps/source/ffmpeg_sources/libopus-1.2.tar.gz \
    "https://archive.mozilla.org/pub/opus/opus-1.2.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf libopus-1.2.tar.gz && \
    cd opus-1.2 && autoreconf -fiv && ./configure --prefix="/apps/install" --enable-shared && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libspeex:
RUN wget -nv -O /apps/source/ffmpeg_sources/speex-1.2rc2.tar.gz \
    "http://downloads.xiph.org/releases/speex/speex-1.2rc2.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf speex-1.2rc2.tar.gz && \
    cd speex-1.2rc2 && LDFLAGS="-L/apps/install/lib" CPPFLAGS="-I/apps/install/include" \
    ./configure --prefix="/apps/install" --enable-shared && make -j$(nproc) && make install && \
    make distclean && ldconfig

# libvorbis:
RUN wget -nv -O /apps/source/ffmpeg_sources/libvorbis-1.3.5.tar.gz \
    "http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.5.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf libvorbis-1.3.5.tar.gz && \
    cd libvorbis-1.3.5 && LDFLAGS="-L/apps/install/lib" CPPFLAGS="-I/apps/install/include" \
    ./configure --prefix="/apps/install" --with-ogg="/apps/install" --enable-shared && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libtheora:
RUN wget -nv -O /apps/source/ffmpeg_sources/libtheora-1.1.1.tar.gz \
    "http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf libtheora-1.1.1.tar.gz && \
    cd libtheora-1.1.1 && ./configure --prefix="/apps/install" \
    --with-ogg="/apps/install" --enable-shared && make -j$(nproc) && make install && \
    make  distclean && ldconfig

# libvpx:
RUN wget -nv -O /apps/source/ffmpeg_sources/v1.6.1.tar.gz \
    "https://codeload.github.com/webmproject/libvpx/tar.gz/v1.6.1" && \
    cd /apps/source/ffmpeg_sources && tar xzf v1.6.1.tar.gz && cd libvpx-1.6.1 && \
    ./configure --prefix="/apps/install" --enable-shared --enable-vp8 \
    --enable-vp9 --enable-pic --disable-debug --disable-examples --disable-docs \
    --as=yasm && make -j$(nproc) && make install && make distclean && ldconfig

# libx264:
RUN wget -nv -O /apps/source/ffmpeg_sources/x264-snapshot-20170226-2245-stable.tar.bz2 \
    "http://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-20170226-2245-stable.tar.bz2" && \
    cd /apps/source/ffmpeg_sources && tar xvjf x264-snapshot-20170226-2245-stable.tar.bz2 && \
    cd x264-snapshot-20170226-2245-stable && PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" \
    ./configure --prefix="/apps/install" --bindir="/apps/install" --enable-shared --disable-cli && \
    make -j$(nproc) && make install && make distclean && ldconfig

# libx265:
RUN wget -nv -O /apps/source/ffmpeg_sources/x265_2.3.tar.gz \
    "https://download.videolan.org/pub/videolan/x265/x265_2.3.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar xzf x265_2.3.tar.gz && cd x265_2.3/build/linux && \
    MAKEFLAGS="-j" ./multilib.sh && cd 8bit && cmake ../../../source -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
    -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -DCMAKE_INSTALL_PREFIX="/apps/install" && \
    make install && make clean && cd ../10bit && make clean && cd ../12bit && make clean && ldconfig

# xvidcore:
RUN wget -nv -O /apps/source/ffmpeg_sources/xvidcore-1.3.4.tar.gz \
    "http://downloads.xvid.org/downloads/xvidcore-1.3.4.tar.gz" && \
    cd /apps/source/ffmpeg_sources && tar zxf xvidcore-1.3.4.tar.gz && \
    cd xvidcore/build/generic && ./configure --prefix="/apps/install" && \
    make -j$(nproc) && make install && make distclean && ldconfig

# FFmpeg 3.3.3:
RUN cd /apps/source/ffmpeg_sources && git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && \
    cd ffmpeg && git checkout release/3.3 && PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" \
    ./configure --bindir="/apps/install/bin" --disable-libsoxr --enable-avresample \
    --enable-gpl --enable-libopencore-amrnb --enable-libopencore-amrwb \
    --enable-libfdk_aac --enable-libmp3lame --enable-libopus --enable-libspeex \
    --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 \
    --enable-libx265 --enable-libxvid --enable-nonfree --enable-openssl \
    --enable-shared --enable-version3 --extra-cflags="-I/apps/install/include" \
    --extra-ldflags="-L/apps/install/lib" --extra-libs=-ldl --prefix="/apps/install" && \
    make -j$(nproc) && make install && make distclean && ln -s /apps/install/bin/ffmpeg /usr/bin/ffmpeg && \
    ldconfig

################################################################################
# Build Google Protocol Buffers                                                #
################################################################################

# Google protocol buffers 2.5.0:
RUN wget -nv -O /apps/source/google_sources/protobuf-2.5.0.tar.gz \
    "https://github.com/google/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz" && \
    cd /apps/source/google_sources && tar xzf protobuf-2.5.0.tar.gz && cd protobuf-2.5.0 && \
    ./configure --prefix=/apps/install && make -j8 && make install && make distclean && \
    ldconfig && ln -s /apps/install/bin/protoc /usr/local/bin/protoc && \
    ln -sf /usr/lib64/libuuid.so.1.3.0 /usr/lib64/libuuid.so

################################################################################
# Build OpenCV                                                                 #
################################################################################

# OpenCV 3.3.0:
RUN cd /apps/source/opencv_sources && git clone https://github.com/opencv/opencv.git && \
    cd opencv && git checkout 3.3.0 && mkdir release && cd release && \
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
    -DWITH_PVAPI:BOOL="0" -DENABLE_CXX11:BOOL=“1” .. && \
    make -j$(nproc) && make install && \
    sh -c 'echo "/apps/install/opencv3.3.0/lib" >> /etc/ld.so.conf.d/mpf-x86_64.conf' && \
    ln -sf /apps/install/opencv3.3.0 /opt/opencv-3.3.0 && \
    ln -sf /apps/install/opencv3.3.0/include/opencv2 /usr/local/include/opencv2 && \
    ln -sf /apps/install/opencv3.3.0/include/opencv /usr/local/include/opencv && \
    ldconfig && export OpenCV_DIR=/opt/opencv-3.3.0/share/OpenCV

################################################################################
# Build Component-Specific Dependencies                                        #
################################################################################

# dlib
RUN wget -nv -O /apps/source/config4cpp.tar.gz "http://www.config4star.org/download/config4cpp.tar.gz" && \
    cd /apps/source && tar xvzf config4cpp.tar.gz && cd config4cpp && make && \
    cd /apps/source/dlib-sources && wget -nv -O /apps/source/dlib-sources/dlib-18.18.tar.bz2 \
    "http://dlib.net/files/dlib-18.18.tar.bz2" && tar xvjf dlib-18.18.tar.bz2 && \
    cd dlib-18.18/dlib && mkdir build && cd build && cmake3 ../ && \
    cmake3 --build . --config Release && make install

# Leptonica 1.75.0:
RUN wget -nv -O /apps/source/tesseract_sources/leptonica-1.75.0.tar.gz \
    "https://github.com/DanBloomberg/leptonica/archive/1.75.0.tar.gz" && \
    cd /apps/source/tesseract_sources &&  tar xvzf leptonica-1.75.0.tar.gz && \
    cd /apps/source/tesseract_sources/leptonica-1.75.0 && mkdir build && cd build && \
    cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && make install && \
    ldconfig

# Tesseract 4.0.0:
RUN wget -nv -O /apps/source/tesseract_sources/tesseract-4.0.0.tar.gz \
    "https://github.com/tesseract-ocr/tesseract/archive/4.0.0.tar.gz" && \
    cd /apps/source/tesseract_sources && tar xzf tesseract-4.0.0.tar.gz && \
    mkdir /apps/source/tesseract_sources/tesseract-4.0.0/build && cd /apps/source/tesseract_sources/tesseract-4.0.0/build && \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig cmake3 -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && make install && \
    ldconfig

# OpenALPR 2.3.0:
RUN cd /apps/source/openalpr_sources && git clone https://github.com/openalpr/openalpr.git && \
    cd openalpr && git checkout 6ead2fb8f72ac1929a2e04912c5795af0bf37761 && \
    mkdir src/build && cd src/build && \
    cmake3 -D CMAKE_CXX_STANDARD=11 -D CMAKE_CXX_STANDARD_REQUIRED=ON -D Leptonica_LIB=/usr/local/lib/libleptonica.so \
    -D CMAKE_INSTALL_PREFIX:PATH=/usr/local -D WITH_DAEMON=OFF .. && \
    make install -j && \
    ldconfig

# ImageMagick6:
RUN yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm && \
    yum --enablerepo=remi install -y ImageMagick6 ImageMagick6-c++ \
    ImageMagick6-c++-devel ImageMagick6-devel ImageMagick6-libs && \
    yum clean all && rm -rf /var/cache/yum/*

# Install locales:
RUN sed -i "/^override_install_lang/d" /etc/yum.conf && \
    yum reinstall -y glibc-common && \
    yum clean all && rm -rf /var/cache/yum/*

################################################################################
# Build ActiveMQ                                                               #
################################################################################

# Apache Portable Runtime (APR) 1.5.2:
RUN wget -nv -O /apps/source/apache_sources/apr-1.5.2.tar.gz \
    "http://archive.apache.org/dist/apr/apr-1.5.2.tar.gz" && \
    cd /apps/source/apache_sources && tar -zxvf apr-1.5.2.tar.gz && \
    cd /apps/source/apache_sources/apr-1.5.2 && ./configure --prefix=/apps/install && \
    make -j8 && make install && make distclean && ldconfig

# apr-util 1.5.4:
RUN wget -nv -O /apps/source/apache_sources/apr-util-1.5.4.tar.gz \
    "http://archive.apache.org/dist/apr/apr-util-1.5.4.tar.gz" && \
    cd /apps/source/apache_sources && tar -xzvf apr-util-1.5.4.tar.gz && \
    cd /apps/source/apache_sources/apr-util-1.5.4 && \
    ./configure --with-apr=/apps/install --prefix=/apps/install && \
    make -j8 && make install && make distclean && ldconfig

# Activemqcpp 3.9.0:
RUN wget -nv -O /apps/source/apache_sources/activemq-cpp-library-3.9.0-src.tar.gz \
    "https://archive.apache.org/dist/activemq/activemq-cpp/3.9.0/activemq-cpp-library-3.9.0-src.tar.gz" && \
    cd /apps/source/apache_sources && tar zxf activemq-cpp-library-3.9.0-src.tar.gz && \
    cd /apps/source/apache_sources/activemq-cpp-library-3.9.0 && ./autogen.sh && \
    ./configure --disable-ssl --prefix="/apps/install" --with-apr=/apps/install && \
    make -j8 && make install && make distclean && ldconfig && \
    ln -s /apps/install/lib/libactivemq-cpp.so.19.0.0 /usr/lib/libactivemq-cpp.so

################################################################################
# NVIDIA CUDA toolkit setup                                                    #
################################################################################

RUN mkdir -p /apps/source/cuda && cd /apps/source/cuda && \
    wget -nv -O cuda_9.0.176_384.81_linux.run \
    "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run" && \
    cd /apps/source/cuda && sh cuda_9.0.176_384.81_linux.run --toolkit \
    --toolkitpath=/apps/install/cuda-9.0 --silent --verbose && \
    ls -l /usr/local/cuda /apps/install/cuda-9.0 && \
    echo "PATH=\$PATH:/usr/local/cuda/bin" >> /etc/profile.d/mpf.sh && \
    . /etc/profile.d/mpf.sh && echo "/usr/local/cuda/lib64" >> \
    /etc/ld.so.conf.d/mpf-x86_64.conf

################################################################################
# Build Google Test Framework                                                  #
################################################################################

# Google Test 1.8.1:
RUN mkdir /apps/source/gtest_sources
RUN cd /apps/source/gtest_sources && git clone https://github.com/google/googletest.git googletest && \
    cd googletest && git checkout release-1.8.1 && mkdir release && cd release && \
    PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" cmake3 .. && \
    make -j$(nproc) && make install && ldconfig

################################################################################
# For Tests: Install yum Dependencies                                          #
################################################################################

RUN yum install -y git asciidoc rpm-build \
    python2-devel PyYAML python-httplib2 python-jinja2 libtomcrypt \
    python-paramiko python-six sshpass which mysql dos2unix ansible && \
    yum clean all && rm -rf /var/cache/yum/*

# TODO: For some reason this needs to be a separate step. I think it's because the
#   mirror it choses for the other yum install does not have python-keyczar.
#   This happens even if python-keyczar is the first thing in the list.
RUN yum install -y python-keyczar && yum clean all

# Update timeout for component deployment tests
RUN echo 'gather_timeout = 60' >> /etc/ansible/ansible.cfg

################################################################################
# For Tests: Link ffserver and ffprobe                                         #
################################################################################

RUN ln -s /apps/install/bin/ffserver /usr/bin/ffserver && \
    ln -s /apps/install/bin/ffprobe /usr/bin/ffprobe

################################################################################
# For Tests: Configure Environment Variables                                   #
################################################################################

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI=failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV THIS_MPF_NODE=localhost
# JGROUPS_TCP_ADDRESS set in docker-entrypoint-test.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV PATH=$PATH:$MPF_HOME/bin
ENV TOMCAT_BASE_URL=http://$THIS_MPF_NODE:8181

# TDOD move this to install java section
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.212.b04-0.el7_6.x86_64
RUN yum -y install java-1.8.0-openjdk-devel && \
    alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 20000 && \
    alternatives --install /usr/bin/jar jar $JAVA_HOME/bin/jar 20000 && \
    alternatives --install /usr/bin/javac javac $JAVA_HOME/bin/javac 20000 && \
    alternatives --install /usr/bin/javaws javaws $JAVA_HOME/jre/bin/javaws 20000 && \
    alternatives --set java $JAVA_HOME/jre/bin/java && \
    alternatives --set javaws $JAVA_HOME/jre/bin/javaws && \
    alternatives --set javac $JAVA_HOME/bin/javac && \
    alternatives --set jar $JAVA_HOME/bin/jar; \
    alternatives --install /usr/bin/jar jar $JAVA_HOME/bin/jar 20000 && \
    alternatives --set jar $JAVA_HOME/bin/jar

# The workflow manager must be added as an mpf-child so that plugin packages are
# extracted at startup, which is necessary for component auto-registration.
RUN echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts;

################################################################################
# Prepare Entrypoint                                                           #
################################################################################

COPY *.sh /home/mpf/
RUN dos2unix -q /home/mpf/*.sh
ENTRYPOINT ["/home/mpf/docker-entrypoint.sh"]

################################################################################
# Labels                                                                       #
################################################################################

ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_SHAS

# Clear inherited labels from CentOS 7.4.1708 base image.
# TODO: Remove these when we start using a newer CentOS base image.
LABEL build-date= \
      license= \
      name= \
      vendor=

# Set labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="Mixed" \
      org.label-schema.name="OpenMPF Build Environment" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://openmpf.github.io" \
      org.label-schema.vcs-ref=$BUILD_SHAS \
      org.label-schema.vcs-url="https://github.com/openmpf" \
      org.label-schema.vendor=MITRE \
      org.label-schema.version=$BUILD_VERSION
