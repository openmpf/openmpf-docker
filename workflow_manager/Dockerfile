FROM mpf_build

# probably do nothing

# a new container can be made to include only the WAR file and a JRE
FROM centos:7.4.1708

ENV MPF_HOME=/opt/mpf
VOLUME $MPF_HOME/share

COPY --from=mpf_build /apps/install/ /apps/install/
COPY --from=mpf_build /opt/apache-tomcat/ /opt/apache-tomcat/
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/mpf-component-build/plugin-packages \
    $MPF_HOME/share/components
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/install/ \
    $MPF_HOME
COPY --from=mpf_build /home/mpf/openmpf-projects/openmpf/trunk/ansible/ \
    /home/mpf/openmpf-projects/openmpf/trunk/ansible/
#   /home/mpf/openmpf-projects/openmpf/trunk/install/
COPY --from=mpf_build /etc/ld.so.conf.d/ /etc/ld.so.conf.d/

# Install Oracle JDK:
COPY --from=mpf_build /apps/bin/jdk-8u144-linux-x64.rpm /apps/bin/jdk-8u144-linux-x64.rpm
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

# Install Ansible dependencies
RUN yum update -y; yum install -y epel-release git asciidoc rpm-build \
    python2-devel PyYAML python-httplib2 python-jinja2 libtomcrypt \
    python-paramiko python-six sshpass which python-keyczar; yum clean all

# for some reason this needs to be a seperate step. I think it's because the
#   mirror is choses for the other yum install does not have python-keyczar
RUN yum install -y python-keyczar; yum clean all

# Ansible
RUN mkdir -p /apps/source/ansible_sources; cd /apps/source/ansible_sources; \
    git clone https://github.com/ansible/ansible.git --recursive; \
    cd ansible; git checkout e71cce777685f96223856d5e6cf506a9ea2ef3ff; \
    git submodule update --init --recursive; \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/core; \
    git checkout 36f512abc1a75b01ae7207c74cdfbcb54a84be54; \
    cd /apps/source/ansible_sources/ansible/lib/ansible/modules/extras; \
    git checkout 32338612b38d1ddfd0d42b1245c597010da02970; \
    cd /apps/source/ansible_sources/ansible; make rpm; \
    cd /apps/source/ansible_sources/ansible; rpm -Uvh ./rpm-build/ansible-*.noarch.rpm

RUN ldconfig

ENV AMQ_HOST=activemq
ENV MYSQL_HOST=mysql_database
ENV JGROUPS_TCP_ADDRESS=workflow_manager
ENV THIS_MPF_NODE=workflow_manager
ENV CORE_MPF_NODES=localhost
ENV ACTIVE_MQ_HOST=failover://(tcp://$AMQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1
ENV no_proxy=localhost
ENV MPF_USER=mpf
ENV MPF_LOG_PATH=$MPF_HOME/logs
ENV LD_LIBRARY_PATH=/usr/lib64:$MPF_HOME/lib
ENV CATALINA_OPTS="-server -Xms256m -XX:PermSize=512m -XX:MaxPermSize=512m -Duser.country=US -Djava.library.path=$MPF_HOME/lib -Dtransport.guarantee='NONE' -Dweb.rest.protocol='http'"
ENV JGROUPS_FILE_PING_LOCATION=$MPF_HOME/share/nodes

RUN echo '[mpf-master]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts; \
    echo '' >> /etc/ansible/hosts; echo '[mpf-child]' >> /etc/ansible/hosts; \
    echo $THIS_MPF_NODE >> /etc/ansible/hosts

EXPOSE 8080
ENTRYPOINT ["/opt/apache-tomcat/bin/catalina.sh","run"]
