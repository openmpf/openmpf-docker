FROM openjdk
RUN apt-get update
RUN apt-get install python

# # Build commands
# RUN cd $mpfPath/trunk/node-manager
# RUN mvn install -Pjenkins -DskipTests -Dmaven.test.skip=true -DskipITs
#
# RUN $mpfPath/trunk/mpf-install
# RUN mvn install -Pjenkins -DskipTests -Dmaven.test.skip=true -DskipITs -f node-manager-only-pom.xml

RUN echo "while true; do echo 'Node manager running'; sleep 30; done" > /home/run.sh
ENTRYPOINT ["sh", "/home/run.sh"]
#ENTRYPOINT [systemctl,start,node-manager]
