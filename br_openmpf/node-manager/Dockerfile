FROM br-openmpf-build as openmpf-build

FROM centos:7

# The centos:7 image sets this yum property to en_US.utf8 which prevents other locales (including other Engish locales)
# from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save

RUN yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && yum install -y java-11-openjdk ffmpeg \
    && yum clean all && rm -rf /var/cache/yum/*


ENV MPF_HOME /opt/mpf

COPY --from=openmpf-build /build-artifacts/install $MPF_HOME

COPY --from=openmpf-build /build-artifacts/plugins $MPF_HOME/plugins

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MYSQL_HOST=mysql-database
ENV THIS_MPF_NODE=node-manager
ENV CORE_MPF_NODES=$THIS_MPF_NODE

ENV JGROUPS_TCP_ADDRESS=$THIS_MPF_NODE
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost,$THIS_MPF_NODE
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
ENV MASTER_MPF_NODE=workflow-manager
ENV MAIL=/var/spool/mail/mpf
ENV PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$MPF_HOME/bin:/usr/bin/
ENV HOME=/home/mpf
ENV LOGNAME=mpf
ENV JAVA_HOME=/usr/lib/jvm/jre-11



COPY docker-entrypoint.sh /home/mpf/docker-entrypoint.sh
ENTRYPOINT ["/home/mpf/docker-entrypoint.sh"]
