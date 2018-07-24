FROM mpf_build

# probably do nothing

# a new container can be made to include only a JRE and executables needed
FROM centos:7.4.1708

ENV MPF_HOME=/opt/mpf

# TODO the more steps that can be kept the same (and in the same order) as the
#   workflow_manager Dockerfile, the more docker can share the build steps
#   between the containers. All shared steps (installing java, copying files
#   from mpf_build) should be moved to the top of both Dockerfiles.

# Create the MPF user
RUN useradd -d /home/mpf -ms /bin/bash -g wheel -p mpf mpf

COPY --from=mpf_build /apps/install/ /apps/install/
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ \
    /opt/mpf/
COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
COPY --from=mpf_build /etc/profile.d/mpf.sh /etc/profile.d/mpf.sh

# Exract tar.gz (using tar xzf) components to $MPF_HOME/plugins
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages \
    $MPF_HOME/share/components
# Extract components
RUN mkdir $MPF_HOME/plugins; cd $MPF_HOME/plugins; \
    for file in $MPF_HOME/share/components/*.tar.gz; do tar xzf "$file"; done

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
RUN yum update -y; yum install -y log4cxx libdc1394 unzip libjpeg-turbo libpng \
    libtiff jasper-libs gtk2 atk pango gdk-pixbuf2 cairo fontconfig gstreamer \
    gstreamer-plugins-base libv4l mesa-libGLU libSM libICE qt-x11 python-pip \
    python-virtualenv initscripts sudo ; yum clean all

VOLUME /opt/mpf/share

# Create log path
RUN mkdir -p /opt/mpf/share/logs/node_manager/; chown mpf /opt/mpf/share/logs/node_manager

RUN cp -a ${MPF_HOME}/bin/* /bin/

# Link ffmpeg
RUN ln -s /apps/install/bin/ffmpeg /usr/bin/ffmpeg

# The commneted out variables are the exact values found on an mpf child host
ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI=failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV JGROUPS_TCP_ADDRESS=workflow_manager
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
# ENV JGROUPS_FILE_PING_LOCATION=/opt/mpf/share/nodes
ENV no_proxy=localhost,node_manager
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# ENV MPF_LOG_PATH=/opt/mpf/share/logs
ENV THIS_MPF_NODE=node_manager
# ENV LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$MPF_HOME/lib
ENV MASTER_MPF_NODE=workflow_manager
ENV MAIL=/var/spool/mail/mpf
ENV PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/mpf/.local/bin:/home/mpf/bin:/usr/bin/
ENV JAVA_HOME=/usr/bin/java
ENV HOME=/home/mpf
ENV LOGNAME=mpf

# This shouldn't be needed, but for some reason the node-manager script is not
#   able to see the ENV variables
RUN echo "export JAVA_HOME=/usr" >> /etc/profile.d/mpf.sh; \
    echo "export MPF_HOME=/opt/mpf" >> /etc/profile.d/mpf.sh; \
    echo "export USER=root" >> /etc/profile.d/mpf.sh; \
    echo "export THIS_MPF_NODE=node_manager" >> /etc/profile.d/mpf.sh; \
    echo "export MASTER_MPF_NODE=workflow_manager" >> /etc/profile.d/mpf.sh; \
    echo "export MPF_LOG_PATH=$MPF_HOME/share/logs" >> /etc/profile.d/mpf.sh; \
    echo "export JGROUPS_TCP_ADDRESS=node_manager" >> /etc/profile.d/mpf.sh; \
    echo "export JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes" >> /etc/profile.d/mpf.sh;

# RUN echo "while true; do echo 'Node manager running'; sleep 30; done" > /home/run.sh
# ENTRYPOINT ["sh", "/home/run.sh"]
ENTRYPOINT ["/bin/bash","-c","rm -f $MPF_HOME/share/nodes/MPF_Channel/*node_manager*.list && $MPF_HOME/libexec/node-manager start && tail -f $MPF_HOME/share/logs/node_manager/log/node-manager.log"]
# CMD ["/bin/bash"]
