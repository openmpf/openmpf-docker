FROM webcenter/activemq
RUN sed -i '27s/.*/#ACTIVEMQ_OPTS_MEMORY="-Xms64M -Xmx1G"/' /opt/activemq/bin/env
RUN sed -i '40s/.*/<broker xmlns="http:\/\/activemq.apache.org\/schema\/core" brokerName="localhost" dataDirectory="${activemq.data}" persistent="false">/' /opt/activemq/conf/activemq.xml
RUN sed -i '44s/.*/<policyEntries>\n<policyEntry queue=">" prioritizedMessages="true" useCache="false" expireMessagesPeriod="0" queuePrefetch="1" \/>\n/' /opt/activemq/conf/activemq.xml
RUN sed -i '72s/.*/<managementContext createConnector="true"\/>/' /opt/activemq/conf/activemq.xml
RUN sed -i '52s/.*/log4j.appender.logfile.layout.ConversionPattern=%d %p [%t] %c - %m%n/' /opt/activemq/conf/log4j.properties

# ENTRYPOINT ["/opt/activemq/bin/activemq", "start"]
