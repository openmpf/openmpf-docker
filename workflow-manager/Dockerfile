FROM mpf_build

# probably do nothing

# a new container can be made to include only the WAR file and a JRE
FROM openjdk:8-jdk
COPY --from=mpf_build /opt/apache-tomcat/webapps/workflow-manager.war /opt/apache-tomcat/webapps/workflow-manager.war
COPY --from=mpf_build /apps/install/* /apps/install/
# COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install TODO
COPY --from=mpf_build /opt/apache-tomcat/bin/catalina.sh /opt/apache-tomcat/bin/catalina.sh
COPY --from=mpf_build /opt/apache-tomcat/bin/ /opt/apache-tomcat/
RUN mkdir -p /usr/java/latest/; cp -a /docker-java-home/bin/ /usr/java/latest/

#ENV PATH=/apps/install/bin
ENV MPF_HOME=/home/mpf/openmpf-projects/openmpf/trunk/install
ENV AMQ_HOST=activemq
ENV ACTIVE_MQ_HOST=failover://(tcp://$AMQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV jmx.amq.broker.uri=service:jmx:rmi:///jndi/rmi://${AMQ_HOST:localhost}:1099/jmxrmi
ENV jdbc.url=jdbc:simon:mysql://${MYSQL_HOST:localhost}:3306/mpf
ENV REDIS_HOST=redis
ENV MYSQL_HOST=mysql_database
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/logs
ENV JAVA_HOME=/docker-java-home
ENV THIS_MPF_NODE=tomcat
ENV ALL_MPF_NODES=$THIS_MPF_NODE[7800]
ENV CATALINA_OPTS="-server -Xms256m -XX:PermSize=512m -XX:MaxPermSize=512m -Djgroups.tcp.port=7800 -Djava.library.path=$MPF_HOME/lib -Djgroups.tcpping.initial_hosts='$ALL_MPF_NODES' -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"

EXPOSE 8080

ENTRYPOINT ["/opt/apache-tomcat/bin/catalina.sh","run"]
