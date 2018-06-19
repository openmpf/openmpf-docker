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

# Install needed build dependencies
RUN yum install -y git python-pip python-devel python-setuptools file \
    python-setuptools-devel gcc gcc-c++ make autoconf automake \
    libtool; yum clean all

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
RUN cd /apps/bin/apache; tar xzvf apache-tomcat-7.0.72.tar.gz
RUN mkdir -p /usr/share/apache-tomcat; \
    cp -Rf /apps/bin/apache/apache-tomcat-7.0.72/* /usr/share/apache-tomcat/
RUN chown -R mpf /usr/share/apache-tomcat; chmod -R 755 /usr/share/apache-tomcat
RUN ln -s /usr/share/apache-tomcat /opt/apache-tomcat
RUN perl -i -p0e 's/<!--\n    <Manager pathname="" \/>\n      -->.*?/<!-- -->\n    <Manager pathname="" \/>/s' /opt/apache-tomcat/conf/context.xml
RUN rm -rf /opt/apache-tomcat/webapps/*

# Apache Maven 3.3.3:
RUN wget -nv -O /apps/bin/apache/apache-maven-3.3.3-bin.tar.gz \
    "https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
RUN cd /apps/bin/apache; tar xzvf apache-maven-3.3.3-bin.tar.gz
RUN mkdir /opt/apache-maven; cp -Rf /apps/bin/apache/apache-maven-3.3.3/* /opt/apache-maven/
RUN chown -R mpf /opt/apache-maven;

### BUILD DEPENDENCIES

# Cmake 2.8.12.2
RUN wget -nv -O /apps/source/cmake_sources/cmake-2.8.12.2.tar.gz \
    "https://cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz";

RUN cd /apps/source/cmake_sources; tar xvzf cmake-2.8.12.2.tar.gz; \
    cd cmake-2.8.12.2; chmod +x *; ./configure --prefix=/apps/install; make -j; \
    make install;
RUN ldconfig; ln -s /apps/install/bin/cmake /usr/local/bin/cmake;

# FFmpeg 3.3.3
RUN wget -nv -O /apps/source/ffmpeg_sources/opencore-amr-0.1.4.tar.gz \
    "https://downloads.sf.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.4.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xvzf opencore-amr-0.1.4.tar.gz; \
    cd opencore-amr-0.1.4; autoreconf -fiv; \
    ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libfdk_aac
RUN wget -nv -O /apps/source/ffmpeg_sources/fdk-aac-0.1.5.tar.gz \
    "https://github.com/mstorsjo/fdk-aac/archive/v0.1.5.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xvzf fdk-aac-0.1.5.tar.gz; \
    cd fdk-aac-0.1.5; autoreconf -fiv; ./configure --prefix="/apps/install" --enable-shared; \
    make; make install; make distclean; ldconfig;

# libmp3lame
RUN wget -nv -O /apps/source/ffmpeg_sources/lame-3.99.5.tar.gz \
    "http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz"; \
    cd /apps/source/ffmpeg_sources; tar xzvf lame-3.99.5.tar.gz; cd lame-3.99.5; \
    ./configure --prefix="/apps/install" --bindir="/apps/install/bin" --enable-shared --enable-nasm; \
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
# # OpenMPF Administrative Tools:
# RUN sudo -E pip install /home/mpf/openmpf-projects/openmpf/trunk/bin/mpf-scripts

# When build is finished and WAR file is created, a new container can be made
#   to include only the WAR file and a JRE
# FROM openjdk:8-jdk
# COPY --from=build target/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war
RUN echo "while true; do echo 'Tomcat running'; sleep 5; done" > /home/mpf/run.sh
ENTRYPOINT ["sh", "/home/mpf/run.sh"]
# ENTRYPOINT ["/opt/apache-tomcat/bin/catalina.sh","run"]
