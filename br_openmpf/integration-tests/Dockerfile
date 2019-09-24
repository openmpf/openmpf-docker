# syntax=docker/dockerfile:experimental


#########################
# Separate stage so we don't have to re-download Tomcat when openmpf-build changes
FROM centos:7 as get_tomcat
RUN cd /opt \
    && curl -SL 'http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.41/bin/apache-tomcat-8.5.41.tar.gz' \
        | tar --extract --gzip \
    && ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat \
    && rm -rf /opt/apache-tomcat/webapps/examples/ \
    && rm -rf /opt/apache-tomcat/webapps/docs/ \
    && rm -rf /opt/apache-tomcat/webapps/ROOT/ \
    # Configure Tomcat cache size:
    # https://stackoverflow.com/questions/26893297/tomcat-8-throwing-org-apache-catalina-webresources-cache-getresource-unable-to
    && sed -i '24s/.*/    <WatchedResource>$\{catalina\.ba\se\}\/conf\/web.xml<\/WatchedResource>\n    <Resources cachingAllowed="true" cacheMaxSize="100000" \/>/' \
        /opt/apache-tomcat/conf/context.xml




#########################
# Separate stage so we don't have to re-download maven dependencies when openmpf-build changes
FROM centos:7 as get_mvn_dependencies

RUN yum install -y java-11-openjdk \
    && yum clean all && rm -rf /var/cache/yum/*

ENV JAVA_HOME=/usr/lib/jvm/jre-11

RUN cd /opt \
    && curl --location 'https://archive.apache.org/dist/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz' \
    | tar --extract --gzip \
    && ln --symbolic /opt/apache-maven-3.3.3/bin/mvn /usr/local/bin

RUN mvn dependency:get -Dartifact=org.apache.maven.plugins:maven-surefire-plugin:2.22.1
RUN mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit4:2.22.1
RUN mvn dependency:get -Dartifact=org.codehaus.cargo:cargo-maven2-plugin:1.4.8
RUN mvn dependency:get -Dartifact=org.codehaus.cargo:cargo-core-container-tomcat:1.4.8
RUN mvn dependency:get -Dartifact=org.apache.maven.surefire:surefire-junit47:2.22.1


FROM centos:7 as get_wait_for_it
RUN mkdir /scripts \
    && curl --location https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
        > /scripts/wait-for-it.sh \
    && chmod +x /scripts/wait-for-it.sh




################################
FROM br-openmpf-build as openmpf-build

FROM openmpf-build as integration_test


RUN --mount=type=cache,target=/mnt/mvn,id=mvn_cache \
    mkdir -p /root/.m2/repository && cp -r /mnt/mvn/* /root/.m2/repository


COPY --from=get_tomcat /opt/apache-tomcat-8.5.41 /opt/apache-tomcat-8.5.41
RUN ln --symbolic /opt/apache-tomcat-8.5.41 /opt/apache-tomcat

COPY --from=get_mvn_dependencies /root/.m2/repository /root/.m2/repository

COPY --from=get_wait_for_it /scripts/wait-for-it.sh /scripts/wait-for-it.sh

ENV THIS_MPF_NODE=workflow-manager
RUN mkdir -p /etc/ansible \
    && echo '[mpf-child]' >> /etc/ansible/hosts \
    && echo $THIS_MPF_NODE >> /etc/ansible/hosts


ENV MPF_HOME /opt/mpf

RUN ln --symbolic /home/mpf/openmpf-projects/openmpf/trunk/install "$MPF_HOME"

RUN ln --symbolic /build-artifacts/descriptors "$MPF_HOME/plugins"

ENV ACTIVE_MQ_HOST=activemq
ENV ACTIVE_MQ_BROKER_URI="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1"
ENV MYSQL_HOST=mysql-database
# JGROUPS_TCP_ADDRESS set in docker-entrypoint.sh
ENV JGROUPS_TCP_PORT=7800
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes
ENV no_proxy=localhost
ENV MPF_USER=root
ENV MPF_LOG_PATH=$MPF_HOME/share/logs
# Every child node-manager container is treated as a spare node.
ENV CORE_MPF_NODES=''
#ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV LD_LIBRARY_PATH=/usr/lib64:/opt/apache-tomcat/webapps/workflow-manager/WEB-INF/classes
ENV PATH=$PATH:$MPF_HOME/bin
ENV JAVA_HOME=/usr/lib/jvm/jre-11
ENV CATALINA_OPTS "-Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
ENV TOMCAT_BASE_URL=http://localhost:8181


COPY check-test-reports.py /scripts/check-test-reports.py
COPY docker-entrypoint.sh /home/mpf/docker-entrypoint.sh

ENTRYPOINT ["/home/mpf/docker-entrypoint.sh"]

