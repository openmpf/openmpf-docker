FROM openjdk
RUN apt-get update
RUN apt-get install python

RUN echo "while true; do echo 'Node manager running'; sleep 5; done" > /home/run.sh
ENTRYPOINT ["sh", "/home/run.sh"]
#ENTRYPOINT [systemctl,start,node-manager]
