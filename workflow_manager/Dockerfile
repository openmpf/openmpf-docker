FROM mpf_build

# probably do nothing

# a new container can be made to include only the WAR file and a JRE
FROM openjdk:8-jdk
COPY --from=mpf_build /apps/install/ /apps/install/
COPY --from=mpf_build /opt/apache-tomcat/ /opt/apache-tomcat/
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ \
    /home/mpf/openmpf-projects/openmpf/trunk/install/
COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
RUN ldconfig

ENV MPF_HOME=/home/mpf/openmpf-projects/openmpf/trunk/install
ENV AMQ_HOST=activemq
ENV ACTIVE_MQ_HOST=failover://(tcp://$AMQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV MYSQL_HOST=mysql_database
ENV JGROUPS_TCP_ADDRESS=tomcat
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/logs
ENV JAVA_HOME=/docker-java-home
ENV THIS_MPF_NODE=tomcat
ENV CORE_MPF_NODES=localhost
ENV LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$MPF_HOME/lib
ENV CATALINA_OPTS="-server -Xms256m -XX:PermSize=512m -XX:MaxPermSize=512m -Duser.country=US -Djava.library.path=$MPF_HOME/lib -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"

EXPOSE 8080
ENTRYPOINT ["/opt/apache-tomcat/bin/catalina.sh","run"]
