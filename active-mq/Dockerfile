FROM webcenter/activemq
RUN sed -i '27s/.*/# ACTIVEMQ_OPTS_MEMORY="-Xms64M -Xmx1G"/' /opt/activemq/bin/env

COPY activemq.xml /opt/activemq/conf/

RUN sed -i '52s/.*/log4j.appender.logfile.layout.ConversionPattern=%d %p [%t] %c - %m%n/' /opt/activemq/conf/log4j.properties
