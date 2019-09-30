
FROM br-openmpf-build as openmpf-build

FROM centos:7

SHELL ["/bin/bash", "-o", "errexit", "-o", "pipefail", "-c"]

# Change config because the centos:7 image sets this yum property to en_US.utf8 which prevents other locales
# (including other Engish locales) from being installed with GCC.
RUN yum-config-manager --setopt=override_install_langs='' --save; \
    yum install --assumeyes --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
            https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm; \
    yum install --assumeyes java-11-openjdk ffmpeg tomcat-native; \
    yum clean all; \
    rm -rf /var/cache/yum/*;


RUN mkdir /scripts; \
    curl --location https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
        > /scripts/wait-for-it.sh; \
    chmod +x /scripts/wait-for-it.sh;


RUN curl --location 'http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.41/bin/apache-tomcat-8.5.41.tar.gz' \
        | tar --extract --gzip --directory /opt; \
    ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat; \
    rm --recursive /opt/apache-tomcat/webapps/*; \
    # Configure Tomcat cache size:
    # https://stackoverflow.com/questions/26893297/tomcat-8-throwing-org-apache-catalina-webresources-cache-getresource-unable-to
    sed --in-place '24s/.*/    <WatchedResource>$\{catalina\.ba\se\}\/conf\/web.xml<\/WatchedResource>\n    <Resources cachingAllowed="true" cacheMaxSize="100000" \/>/' \
        /opt/apache-tomcat/conf/context.xml;


COPY --from=openmpf-build /build-artifacts/workflow-manager.war /opt/apache-tomcat/webapps/

ENV MPF_HOME /opt/mpf

COPY --from=openmpf-build /build-artifacts/descriptors $MPF_HOME/plugins


ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MYSQL_HOST=mysql-database
ENV REDIS_HOST=redis
ENV THIS_MPF_NODE=workflow-manager
# JGROUPS_TCP_ADDRESS set in docker-entrypoint.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=''
ENV LD_LIBRARY_PATH=/usr/lib64:/opt/apache-tomcat/webapps/workflow-manager/WEB-INF/classes
ENV PATH=$PATH:$MPF_HOME/bin
ENV JAVA_HOME=/usr/lib/jvm/jre-11

# The workflow manager must be added as an mpf-child so that plugin packages are
# extracted at startup, which is necessary for component auto-registration.
RUN mkdir /etc/ansible; \
    echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts;


EXPOSE 8080 8443

COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]
