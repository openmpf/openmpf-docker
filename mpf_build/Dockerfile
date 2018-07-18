FROM centos:7.4.1708 as mpf_build
WORKDIR /home/mpf

# Set up yum repo
RUN yum install -y epel-release deltarpm; yum clean all
RUN yum update -y; yum clean all
RUN yum install sudo -y; yum clean all

# Create the MPF user
RUN useradd -d /home/mpf -ms /bin/bash -g wheel -p mpf mpf

# Create directories for sources
RUN mkdir -p /apps/install/lib; mkdir -p /apps/bin/apache; \
    mkdir /apps/ansible; mkdir -p /apps/source/cmake_sources; \
    mkdir /apps/source/apache_sources; mkdir /apps/source/google_sources; \
    mkdir /apps/source/opencv_sources; mkdir /apps/source/ffmpeg_sources; \
    mkdir /apps/source/dlib-sources; mkdir /apps/source/openalpr_sources; \
    mkdir /apps/source/ansible_sources; \
    chown -R mpf /apps;chmod -R 755 /apps

# Create the OpenMPF ldconfig file:
# Add /apps/install/lib to the OpenMPF ldconfig file:
# Update the shared library cache:
RUN touch /etc/ld.so.conf.d/mpf-x86_64.conf; \
    sh -c 'echo "/apps/install/lib" >> /etc/ld.so.conf.d/mpf-x86_64.conf'; \
    ldconfig

# Install needed build toolchain
RUN yum install -y git python-pip python-devel python-setuptools file \
    python-setuptools-devel gcc gcc-c++ make autoconf automake \
    libtool yasm nasm bzip2 cmake3 numpy perl-File-Find-Rule which \
    libffi-devel openssl-devel apr apr-util apr-util-ldap log4cxx \
    log4cxx-devel qt qt-devel qt-x11 boost boost-devel wget; yum clean all

# C Foreign Function Interface (CFFI):
RUN cd /home/mpf; sudo -E easy_install -U cffi

### BINARY PACKAGES

# Oracle JDK:
RUN cd /apps/bin/; wget -nv \
    https://mirror.its.sfu.ca/mirror/CentOS-Third-Party/NSG/common/x86_64/jdk-8u144-linux-x64.rpm
RUN yum -y localinstall --nogpgcheck /apps/bin/jdk-8u144-linux-x64.rpm
RUN alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_144/jre/bin/java 20000; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --install /usr/bin/javac javac /usr/java/jdk1.8.0_144/bin/javac 20000; \
    alternatives --install /usr/bin/javaws javaws /usr/java/jdk1.8.0_144/jre/bin/javaws 20000; \
    alternatives --set java /usr/java/jdk1.8.0_144/jre/bin/java; \
    alternatives --set javaws /usr/java/jdk1.8.0_144/jre/bin/javaws; \
    alternatives --set javac /usr/java/jdk1.8.0_144/bin/javac; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar;

# TODO pipe all tars into extract command s
#  wget -qO- your_link_here | tar xvz -C /target/directory
# Apache Tomcat 7.0.72:
RUN wget -nv -O /apps/bin/apache/apache-tomcat-7.0.72.tar.gz \
    "http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.72/bin/apache-tomcat-7.0.72.tar.gz"; \
    cd /apps/bin/apache; tar xzf apache-tomcat-7.0.72.tar.gz; \
    mkdir -p /usr/share/apache-tomcat; \
    cp -Rf /apps/bin/apache/apache-tomcat-7.0.72/* /usr/share/apache-tomcat/; \
    chown -R mpf /usr/share/apache-tomcat; chmod -R 755 /usr/share/apache-tomcat; \
    ln -s /usr/share/apache-tomcat /opt/apache-tomcat; \
    perl -i -p0e 's/<!--\n    <Manager pathname="" \/>\n      -->.*?/<!-- -->\n    <Manager pathname="" \/>/s' \
        /opt/apache-tomcat/conf/context.xml; \
    rm -rf /opt/apache-tomcat/webapps/*

# Apache Maven 3.3.3:
RUN wget -nv -O /apps/bin/apache/apache-maven-3.3.3-bin.tar.gz \
    "https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"; \
    cd /apps/bin/apache; tar xzf apache-maven-3.3.3-bin.tar.gz; \
    mkdir /opt/apache-maven; cp -Rf /apps/bin/apache/apache-maven-3.3.3/* /opt/apache-maven/; \
    chown -R mpf /opt/apache-maven; \
    alternatives --install "/usr/bin/mvn" "mvn" "/opt/apache-maven/bin/mvn" 0; \
    alternatives --set mvn /opt/apache-maven/bin/mvn

### BUILD DEPENDENCIES

# Cmake 2.8.12.2
RUN wget -nv -O /apps/source/cmake_sources/cmake-2.8.12.2.tar.gz \
    "https://cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz";
RUN cd /apps/source/cmake_sources; tar xzf cmake-2.8.12.2.tar.gz; \
    cd cmake-2.8.12.2; chmod +x *; ./configure --prefix=/apps/install; make -j; \
    make install;
RUN ldconfig; ln -s /apps/install/bin/cmake /usr/local/bin/cmake;

### FFmpeg 3.3.3

# opencore-amr
RUN wget -nv -O /apps/source/ffmpeg_sources/opencore-amr-0.1.4.tar.gz \
    "https://downloads.sf.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.4.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf opencore-amr-0.1.4.tar.gz; \
    cd opencore-amr-0.1.4; autoreconf -fiv; \
    ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libfdk_aac
RUN wget -nv -O /apps/source/ffmpeg_sources/fdk-aac-0.1.5.tar.gz \
    "https://github.com/mstorsjo/fdk-aac/archive/v0.1.5.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf fdk-aac-0.1.5.tar.gz; \
    cd fdk-aac-0.1.5; autoreconf -fiv; ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libmp3lame
RUN wget -nv -O /apps/source/ffmpeg_sources/lame-3.99.5.tar.gz \
    "http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf lame-3.99.5.tar.gz; cd lame-3.99.5; \
    ./configure --prefix="/apps/install" --bindir="/apps/install/bin" --enable-shared --enable-nasm; \
    make; make install; make distclean; ldconfig;

# libogg
RUN wget -nv -O /apps/source/ffmpeg_sources/libogg-1.3.2.tar.gz \
    "http://downloads.xiph.org/releases/ogg/libogg-1.3.2.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf libogg-1.3.2.tar.gz; \
    cd libogg-1.3.2; ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libopus
RUN wget -nv -O /apps/source/ffmpeg_sources/libopus-1.2.tar.gz \
    "https://archive.mozilla.org/pub/opus/opus-1.2.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf libopus-1.2.tar.gz; \
    cd opus-1.2; autoreconf -fiv; ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libspeex
RUN wget -nv -O /apps/source/ffmpeg_sources/speex-1.2rc2.tar.gz \
    "http://downloads.xiph.org/releases/speex/speex-1.2rc2.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf speex-1.2rc2.tar.gz; \
    cd speex-1.2rc2; LDFLAGS="-L/apps/install/lib" CPPFLAGS="-I/apps/install/include" \
    ./configure --prefix="/apps/install" --enable-shared; make; make install; \
    make distclean; ldconfig;

# libvorbis
RUN wget -nv -O /apps/source/ffmpeg_sources/libvorbis-1.3.5.tar.gz \
    "http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.5.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf libvorbis-1.3.5.tar.gz; \
    cd libvorbis-1.3.5; LDFLAGS="-L/apps/install/lib" CPPFLAGS="-I/apps/install/include" \
    ./configure --prefix="/apps/install" --with-ogg="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libtheora
RUN wget -nv -O /apps/source/ffmpeg_sources/libtheora-1.1.1.tar.gz \
    "http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf libtheora-1.1.1.tar.gz; \
    cd libtheora-1.1.1; ./configure --prefix="/apps/install" \
    --with-ogg="/apps/install" --enable-shared; make; make install; \
    make distclean; ldconfig;

# libvpx
RUN wget -nv -O /apps/source/ffmpeg_sources/v1.6.1.tar.gz \
    "https://codeload.github.com/webmproject/libvpx/tar.gz/v1.6.1"; \
    cd /apps/source/ffmpeg_sources; tar xzf v1.6.1.tar.gz; cd libvpx-1.6.1; \
    ./configure --prefix="/apps/install" --enable-shared --enable-vp8 \
    --enable-vp9 --enable-pic --disable-debug --disable-examples --disable-docs \
    --as=yasm; make; make install; make distclean; ldconfig;

# libx264
RUN wget -nv -O /apps/source/ffmpeg_sources/x264-snapshot-20170226-2245-stable.tar.bz2 \
    "ftp://ftp.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-20170226-2245-stable.tar.bz2"; \
    cd /apps/source/ffmpeg_sources; tar xvjf x264-snapshot-20170226-2245-stable.tar.bz2; \
    cd x264-snapshot-20170226-2245-stable; PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" \
    ./configure --prefix="/apps/install" --bindir="/apps/install" --enable-shared --disable-cli; \
    make; make install; make distclean; ldconfig;

# libx265
RUN wget -nv -O /apps/source/ffmpeg_sources/x265_2.3.tar.gz \
    "https://download.videolan.org/pub/videolan/x265/x265_2.3.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzf x265_2.3.tar.gz; cd x265_2.3/build/linux; \
    MAKEFLAGS="-j" ./multilib.sh; cd 8bit; cmake ../../../source -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
    -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -DCMAKE_INSTALL_PREFIX="/apps/install"; \
    make install; make clean; cd ../10bit; make clean; cd ../12bit; make clean; ldconfig;

# xvidcore
RUN wget -nv -O /apps/source/ffmpeg_sources/xvidcore-1.3.4.tar.gz \
    "http://downloads.xvid.org/downloads/xvidcore-1.3.4.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar zxf xvidcore-1.3.4.tar.gz; \
    cd xvidcore/build/generic; ./configure --prefix="/apps/install"; \
    make; make install; make distclean; ldconfig;

# FFmpeg (end)
RUN cd /apps/source/ffmpeg_sources; git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg; \
    cd ffmpeg; git checkout release/3.3; PKG_CONFIG_PATH="/apps/install/lib/pkgconfig" \
    ./configure --bindir="/apps/install/bin" --disable-libsoxr --enable-avresample \
    --enable-gpl --enable-libopencore-amrnb --enable-libopencore-amrwb \
    --enable-libfdk_aac --enable-libmp3lame --enable-libopus --enable-libspeex \
    --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 \
    --enable-libx265 --enable-libxvid --enable-nonfree --enable-openssl \
    --enable-shared --enable-version3 --extra-cflags="-I/apps/install/include" \
    --extra-ldflags="-L/apps/install/lib" --extra-libs=-ldl --prefix="/apps/install"; \
    make; make install; make distclean; ln -s /apps/install/bin/ffmpeg /usr/bin/ffmpeg; \
    ldconfig;

### FFmpeg end

# Google protocol buffers 2.5.0
RUN wget -nv -O /apps/source/google_sources/protobuf-2.5.0.tar.gz \
    "https://github.com/google/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz"; \
    cd /apps/source/google_sources; tar xzf protobuf-2.5.0.tar.gz; cd protobuf-2.5.0; \
    ./configure --prefix=/apps/install; make -j8; make install; make distclean; \
    ldconfig; ln -s /apps/install/bin/protoc /usr/local/bin/protoc; \
    ln -s /usr/lib64/libuuid.so.1.3.0 /usr/lib64/libuuid.so;

# OpenCV 3.3.0
RUN cd /apps/source/opencv_sources; git clone https://github.com/opencv/opencv.git; \
    cd opencv; git checkout 3.3.0; mkdir release; cd release; \
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
    -DWITH_PVAPI:BOOL="0" -DENABLE_CXX11:BOOL=“1” ..; \
    make -j4; make install; \
    sh -c 'echo "/apps/install/opencv3.3.0/lib" >> /etc/ld.so.conf.d/mpf-x86_64.conf'; \
    ln -sf /apps/install/opencv3.3.0 /opt/opencv-3.3.0; \
    ln -sf /apps/install/opencv3.3.0/include/opencv2 /usr/local/include/opencv2; \
    ln -sf /apps/install/opencv3.3.0/include/opencv /usr/local/include/opencv; \
    ldconfig; export OpenCV_DIR=/opt/opencv-3.3.0/share/OpenCV;

# dlib
RUN wget -nv -O /apps/source/config4cpp.tar.gz "http://www.config4star.org/download/config4cpp.tar.gz"; \
    cd /apps/source; tar xvzf config4cpp.tar.gz; cd config4cpp; make; \
    cd /apps/source/dlib-sources; wget -nv -O /apps/source/dlib-sources/dlib-18.18.tar.bz2 \
    "http://dlib.net/files/dlib-18.18.tar.bz2"; tar xvjf dlib-18.18.tar.bz2; \
    cd dlib-18.18/dlib; mkdir build; cd build; cmake3 ../; \
    cmake3 --build . --config Release; make install

# Leptonica 1.72
RUN wget -nv -O /apps/source/openalpr_sources/leptonica-1.72.tar.gz \
    "https://github.com/DanBloomberg/leptonica/archive/v1.72.tar.gz"; \
    cd /apps/source/openalpr_sources; tar xzf leptonica-1.72.tar.gz; \
    mkdir /usr/local/src/openalpr; \
    cp -R /apps/source/openalpr_sources/leptonica-1.72 /usr/local/src/openalpr/; \
    chown -R mpf /usr/local/src/openalpr; chmod -R 755 /usr/local/src/openalpr; \
    cd /usr/local/src/openalpr/leptonica-1.72; ./configure --prefix=/usr/local; \
    make --directory /usr/local/src/openalpr/leptonica-1.72 -j; \
    make --directory /usr/local/src/openalpr/leptonica-1.72 install; \
    make --directory /usr/local/src/openalpr/leptonica-1.72 distclean; \
    ldconfig;

# Tesseract 3.04.00
RUN wget -nv -O /apps/source/openalpr_sources/tesseract-3.04.00.tar.gz \
    "https://github.com/tesseract-ocr/tesseract/archive/3.04.00.tar.gz"; \
    cd /apps/source/openalpr_sources; tar xzf tesseract-3.04.00.tar.gz; \
    wget -nv -O /apps/source/openalpr_sources/tessdata-3.04.00.tar.gz \
    "https://github.com/tesseract-ocr/tessdata/archive/3.04.00.tar.gz"; \
    tar xzf tessdata-3.04.00.tar.gz; mkdir -p /usr/local/src/openalpr/tesseract-ocr; \
    cp -a /apps/source/openalpr_sources/tessdata-3.04.00/. \
    /usr/local/src/openalpr/tesseract-ocr/tessdata/; \
    cp -a /apps/source/openalpr_sources/tesseract-3.04.00/. \
    /usr/local/src/openalpr/tesseract-ocr/; \
    chown -R mpf /usr/local/src/openalpr; chmod -R 755 /usr/local/src/openalpr; \
    cd /usr/local/src/openalpr/tesseract-ocr; sh autogen.sh; ./configure; \
    make --directory /usr/local/src/openalpr/tesseract-ocr -j; \
    make --directory /usr/local/src/openalpr/tesseract-ocr install; \
    ldconfig;

# OpenALPR 2.3.0:
RUN cd /apps/source/openalpr_sources; git clone https://github.com/openalpr/openalpr.git; \
    cd openalpr; git checkout 469c4fd6d782ac63a55246d1073b0f88edd0d230; \
    cp -a /apps/source/openalpr_sources/openalpr /usr/local/src/openalpr/ ; \
    mkdir -p /usr/local/src/openalpr/openalpr/src/build; \
    cd /usr/local/src/openalpr/openalpr/src/build; \
    cmake3 -j --DCmake3 -j_INSTALL_PREFIX:PATH=/usr -D WITH_DAEMON=OFF ../; \
    make --directory /usr/local/src/openalpr/openalpr/src/build -j; \
    make --directory /usr/local/src/openalpr/openalpr/src/build install; \
    ln -sf /usr/local/src/openalpr/openalpr /usr/share/openalpr; \
    cp -a /usr/local/lib/libopenalpr.so /usr/lib/libopenalpr.so; \
    cp /usr/local/lib/libopenalpr.so.2 /usr/lib/libopenalpr.so.2; \
    sh -c 'echo "export TESSDATA_PREFIX=/usr/local/src/openalpr/openalpr/runtime_data/ocr" >> /etc/profile.d/mpf.sh'; \
    ldconfig;

# Apr 1.5.2:
RUN wget -nv -O /apps/source/apache_sources/apr-1.5.2.tar.gz \
    "http://archive.apache.org/dist/apr/apr-1.5.2.tar.gz"; \
    cd /apps/source/apache_sources; tar -zxvf apr-1.5.2.tar.gz; \
    cd /apps/source/apache_sources/apr-1.5.2; ./configure --prefix=/apps/install; \
    make -j8; make install; make distclean; ldconfig;

# Apr-util 1.5.4:
RUN wget -nv -O /apps/source/apache_sources/apr-util-1.5.4.tar.gz \
    "http://archive.apache.org/dist/apr/apr-util-1.5.4.tar.gz"; \
    cd /apps/source/apache_sources; tar -xzvf apr-util-1.5.4.tar.gz; \
    cd /apps/source/apache_sources/apr-util-1.5.4; \
    ./configure --with-apr=/apps/install --prefix=/apps/install; \
    make -j8; make install; make distclean; ldconfig;

# Activemqcpp 3.9.0
RUN wget -nv -O /apps/source/apache_sources/activemq-cpp-library-3.9.0-src.tar.gz \
    "https://archive.apache.org/dist/activemq/activemq-cpp/3.9.0/activemq-cpp-library-3.9.0-src.tar.gz"; \
    cd /apps/source/apache_sources; tar zxf activemq-cpp-library-3.9.0-src.tar.gz; \
    cd /apps/source/apache_sources/activemq-cpp-library-3.9.0; ./autogen.sh; \
    ./configure --disable-ssl --prefix="/apps/install" --with-apr=/apps/install; \
    make -j8; make install; make distclean; ldconfig; \
    ln -s /apps/install/lib/libactivemq-cpp.so.19.0.0 /usr/lib/libactivemq-cpp.so


################################################################################
# Clone the OpenMPF repository * this will change the most often so it should  #
#   be as far down in the Dockerfile are possible                              #
################################################################################
RUN cd /home/mpf; \
    git clone https://github.com/openmpf/openmpf-projects.git --recursive; \
    cd openmpf-projects; git checkout develop; git submodule update --init; \
    cd openmpf; git checkout update-config-docker;

# OpenMPF Administrative Tools:
RUN sudo -E pip install /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts

# Add Maven dependencies
RUN cd /home/mpf; mkdir -p .m2/repository; tar xzf \
    /home/mpf/openmpf-projects/openmpf-build-tools/mpf-maven-deps.tar.gz \
    -C /home/mpf/.m2/repository/; cp -a /home/mpf/.m2/ ~/.m2/

RUN mkdir -p /mpfdata/ansible/install/repo/rpms/management; \
    mkdir /mpfdata/ansible/install/repo/rpms/mpf; \
    mkdir /mpfdata/ansible/install/repo/rpms/mpf-deps; \
    mkdir /mpfdata/ansible/install/repo/files; \
    mkdir /mpfdata/ansible/install/repo/pip; \
    mkdir /mpfdata/ansible/install/repo/tars; \
    mkdir /mpfdata/releases; \
    chown -R mpf /mpfdata

### Build the OpenMPF Package

# Further dependencies TODO move up
RUN pip install --upgrade pip; pip install wheel virtualenv;

# Remove the development properties file:
RUN cd /home/mpf/openmpf-projects/openmpf; \
    rm -f trunk/workflow-manager/src/main/resources/properties/mpf-private.properties

# Copy the development properties file back if you wish to run the OpenMPF on the OpenMPF Build VM
RUN cp /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/properties/mpf-private-example.properties \
    /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/properties/mpf-private.properties

# Set env variables from /etc/profile.d/mpf.sh
ARG PKG_CONFIG_PATH=/apps/install/lib/pkgconfig
ARG CXXFLAGS=-isystem\ /apps/install/include
ENV PATH=$PATH:/apps/install/bin:/opt/apache-maven/bin:/apps/install/lib/pkgconfig:/usr/bin/

# TODO see if this can be converted to use ARG variable, this strategy is
#    very brittle because it's based on line number
RUN sed -i '37s/.*/              p:hostName="redis"/' \
    /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager/src/main/resources/applicationContext-redis.xml;

################################################################################
# Build and Run the Web Application                                            #
#                                                                              #
################################################################################
RUN cd /home/mpf/openmpf-projects/openmpf; \
    cp trunk/workflow-manager/src/main/resources/properties/mpf-private-example.properties \
      trunk/workflow-manager/src/main/resources/properties/mpf-private.properties; \
#    sed -i '11s/.*/# Ex 1: Ungrouped hosts, specify before any group headers.\n[mpf-child]\nlocalhost.localdomain/' /etc/ansible/hosts
    mvn clean install -DskipTests -Dmaven.test.skip=true -DskipITs \
    -Dmaven.tomcat.skip=true  \
    -Dcomponents.build.package.json=/home/mpf/openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/openmpf-open-source-package.json \
    -Dstartup.auto.registration.skip=false \
    -Dcomponents.build.dir=/home/mpf/openmpf-projects/openmpf/mpf-component-build;

RUN cd /home/mpf/openmpf-projects/openmpf/trunk/workflow-manager; \
    rm -rf /opt/apache-tomcat/webapps/workflow-manager*; \
    cp target/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war; \
    cd ../..; cp trunk/install/libexec/node-manager /etc/init.d/;

# For troubleshooting purposes, you may run a bash console in this container
#    using docker run -it <container_id, container_name>
CMD ["/bin/bash"]
