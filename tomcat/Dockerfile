FROM centos:7.4.1708
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
    libtool yasm nasm bzip2; yum clean all

# C Foreign Function Interface (CFFI):
RUN cd /home/mpf; yum install libffi-devel -y; yum clean all
RUN sudo -E easy_install -U cffi

### BINARY PACKAGES

# Oracle JDK:
RUN cd /apps/bin/; yum install wget -y; yum clean all; \
    wget -nv https://mirror.its.sfu.ca/mirror/CentOS-Third-Party/NSG/common/x86_64/jdk-8u144-linux-x64.rpm
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

# Apache Tomcat 7.0.72:
RUN wget -nv -O /apps/bin/apache/apache-tomcat-7.0.72.tar.gz \
    "http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.72/bin/apache-tomcat-7.0.72.tar.gz"
RUN cd /apps/bin/apache; tar xzf apache-tomcat-7.0.72.tar.gz
RUN mkdir -p /usr/share/apache-tomcat; \
    cp -Rf /apps/bin/apache/apache-tomcat-7.0.72/* /usr/share/apache-tomcat/
RUN chown -R mpf /usr/share/apache-tomcat; chmod -R 755 /usr/share/apache-tomcat
RUN ln -s /usr/share/apache-tomcat /opt/apache-tomcat
RUN perl -i -p0e 's/<!--\n    <Manager pathname="" \/>\n      -->.*?/<!-- -->\n    <Manager pathname="" \/>/s' /opt/apache-tomcat/conf/context.xml
RUN rm -rf /opt/apache-tomcat/webapps/*

# Apache Maven 3.3.3:
RUN wget -nv -O /apps/bin/apache/apache-maven-3.3.3-bin.tar.gz \
    "https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
RUN cd /apps/bin/apache; tar xzf apache-maven-3.3.3-bin.tar.gz
RUN mkdir /opt/apache-maven; cp -Rf /apps/bin/apache/apache-maven-3.3.3/* /opt/apache-maven/
RUN chown -R mpf /opt/apache-maven;

### BUILD DEPENDENCIES

# Cmake 2.8.12.2
RUN wget -nv -O /apps/source/cmake_sources/cmake-2.8.12.2.tar.gz \
    "https://cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz";
RUN cd /apps/source/cmake_sources; tar xzf cmake-2.8.12.2.tar.gz; \
    cd cmake-2.8.12.2; chmod +x *; ./configure --prefix=/apps/install; make -j; \
    make install;
RUN ldconfig; ln -s /apps/install/bin/cmake /usr/local/bin/cmake;

# FFmpeg 3.3.3
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
    --enable-vp9 --enable-pic --disable-debug --disable-examples --disable-docs; \
    make; make install; make distclean; ldconfig;

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

# # TODO mount as volume
# RUN mkdir /opt/mpf/; mkdir /opt/mpf/share
#
# ################################################################################
# # Clone the OpenMPF repository * this will change the most often so it should  #
# #   be as far down in the Dockerfile are possible                              #
# ################################################################################
# RUN cd /home/mpf; \
#     git clone https://github.com/openmpf/openmpf-projects.git --recursive
#
# # Copy the mpf user profile script from the extracted source code:
# # Add /apps/install/bin to the system PATH variable:
# RUN cp /home/mpf/openmpf-projects/openmpf/trunk/mpf-install/src/main/scripts/mpf-profile.sh /etc/profile.d/mpf.sh; \
#     sh -c 'echo "PATH=\$PATH:/apps/install/bin" >> /etc/profile.d/mpf.sh'; \
#     . /etc/profile.d/mpf.sh
#
# RUN sed -i '/^PATH/s/$/:\/opt\/apache-maven\/bin/' /etc/profile.d/mpf.sh; \
#     sh -c 'echo "M2_HOME=/opt/apache-maven" >> /etc/profile.d/mpf.sh'
#
# RUN sed -i '/^PATH/s/$/:\/apps\/install\/lib\/pkgconfig/' /etc/profile.d/mpf.sh; \
#     sh -c 'echo "export PKG_CONFIG_PATH=/apps/install/lib/pkgconfig" >> /etc/profile.d/mpf.sh'
#
# # OpenMPF Administrative Tools:
# RUN sudo -E pip install /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts

# When build is finished and WAR file is created, a new container can be made
#   to include only the WAR file and a JRE
# FROM openjdk:8-jdk
# COPY --from=build target/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war
# COPY --from=build /apps/install/* /apps/install
RUN echo "while true; do echo 'Tomcat running'; sleep 5; done" > /home/mpf/run.sh
ENTRYPOINT ["sh", "/home/mpf/run.sh"]
# ENTRYPOINT ["/opt/apache-tomcat/bin/catalina.sh","run"]
