FROM mpf_build

# probably do nothing

# a new container can be made to include only a JRE and executables needed
FROM centos:7.4.1708

ENV MPF_HOME=/opt/mpf

# TODO map ffmpeg
COPY --from=mpf_build /apps/install/ /apps/install/
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ \
    /opt/mpf/
COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
COPY --from=mpf_build /etc/profile.d/mpf.sh /etc/profile.d/mpf.sh

# Exract tar.gz (using tar xzf) components to $MPF_HOME/plugins
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages \
    $MPF_HOME/share/components

COPY --from=mpf_build /apps/bin/jdk-8u144-linux-x64.rpm /apps/bin/jdk-8u144-linux-x64.rpm

RUN ldconfig

#############################
# Child node needs:
#  Node manage jar
#  component libraries
#  plugins directory from tar.gz
#  update data and config
#  * components are registered when tomcat comes up

# Oracle JDK:
RUN yum -y localinstall --nogpgcheck /apps/bin/jdk-8u144-linux-x64.rpm; \
    alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_144/jre/bin/java 20000; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --install /usr/bin/javac javac /usr/java/jdk1.8.0_144/bin/javac 20000; \
    alternatives --install /usr/bin/javaws javaws /usr/java/jdk1.8.0_144/jre/bin/javaws 20000; \
    alternatives --set java /usr/java/jdk1.8.0_144/jre/bin/java; \
    alternatives --set javaws /usr/java/jdk1.8.0_144/jre/bin/javaws; \
    alternatives --set javac /usr/java/jdk1.8.0_144/bin/javac; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar; \
    alternatives --install /usr/bin/jar jar /usr/java/jdk1.8.0_144/bin/jar 20000; \
    alternatives --set jar /usr/java/jdk1.8.0_144/bin/jar;

VOLUME /opt/mpf/share

# - name: Install dependencies
#   yum:
#     name="{{ item }}"
#     state=latest
#     update_cache=yes
#     disablerepo=*
#     enablerepo=mpf-repo
#   environment:
#     no_proxy: "{{ repo_host }}"
#   with_items:
#     - log4cxx
#     - libdc1394
#     - unzip
#     - libjpeg-turbo
#     - libpng
#     - libtiff
#     - jasper-libs
#     - gtk2
#     - atk
#     - pango
#     - gdk-pixbuf2
#     - cairo
#     - fontconfig
#     - gstreamer
#     - gstreamer-plugins-base
#     - libv4l
#     - mesa-libGLU
#     - libSM
#     - libICE
#     - qt-x11
#     - python-pip
#     - python-virtualenv

# The commneted out variables are the exact values found on an mpf child host
ENV AMQ_HOST=activemq
ENV ACTIVE_MQ_HOST=failover://(tcp://$AMQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV JGROUPS_TCP_ADDRESS=workflow_manager
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
# ENV JGROUPS_FILE_PING_LOCATION=/opt/mpf/share/nodes
ENV no_proxy=localhost,node_manager
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/logs
# ENV MPF_LOG_PATH=/opt/mpf/share/logs
ENV THIS_MPF_NODE=node_manager
# ENV LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$MPF_HOME/lib
ENV MASTER_MPF_NODE=workflow_manager
ENV MAIL=/var/spool/mail/mpf
ENV PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/mpf/.local/bin:/home/mpf/bin
ENV HOME=/home/mpf
ENV LOGNAME=mpf

RUN echo "while true; do echo 'Node manager running'; sleep 30; done" > /home/run.sh
ENTRYPOINT ["sh", "/home/run.sh"]
# ENTRYPOINT ["sh","$MPF/bin/start-nodemanager.sh"]
