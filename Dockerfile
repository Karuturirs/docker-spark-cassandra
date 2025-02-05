FROM cassandra:3.11.3

RUN rm /etc/apt/sources.list.d/cassandra.list

# Install OpenJDK-8
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean;

# Fix certificate issues
RUN apt-get update && \
    apt-get install ca-certificates-java && \
    apt-get clean && \
    update-ca-certificates -f;

# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/


# install and configure supervisor + curl
RUN apt-get update && apt-get install -y supervisor curl && rm -rf /var/lib/apt/lists/* && mkdir -p /var/log/supervisor

COPY supervisor.conf/ /supervisor.conf/
ENV SUPERVISOR_CONF_DEFAULT="/supervisor.conf/supervisord-cass.conf" SUPERVISOR_CONF_CASSANDRA="/supervisor.conf/supervisord-cass.conf" SUPERVISOR_CONF_MASTER="supervisor.conf/supervisord-master.conf" \
SUPERVISOR_CONF_WORKER="/supervisor.conf/supervisord-worker.conf"

# download and install spark
RUN apt-get update && \
	apt-get install -y wget
RUN 	wget -O- http://archive.apache.org/dist/spark/spark-2.2.3/spark-2.2.3-bin-hadoop2.7.tgz | tar -xz -C /usr/local/ && \
	cd /usr/local && ln -s spark-2.2.3-bin-hadoop2.7 spark

RUN 	mkdir spark-libs && \
	wget https://repo1.maven.org/maven2/com/datastax/spark/spark-cassandra-connector_2.11/2.3.2/spark-cassandra-connector_2.11-2.3.2.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/com/google/guava/guava/16.0.1/guava-16.0.1.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/net/finmath/finmath-lib/3.0.14/finmath-lib-3.0.14.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/org/scalaz/scalaz-core_2.11/7.2.3/scalaz-core_2.11-7.2.3.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/org/apache/commons/commons-math3/3.6.1/commons-math3-3.6.1.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/org/apache/commons/commons-lang3/3.4/commons-lang3-3.4.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/org/jblas/jblas/1.2.4/jblas-1.2.4.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/org/threeten/threetenbp/1.3.4/threetenbp-1.3.4.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/com/google/code/gson/gson/2.7/gson-2.7.jar -P spark-libs && \
	wget https://repo1.maven.org/maven2/com/twitter/jsr166e/1.1.0/jsr166e-1.1.0.jar -P spark-libs && \
	mv spark-libs/*.jar usr/local/spark/jars && \
	rm -rf spark-libs && \
  	cd usr/local/spark/jars && \
	rm guava-14.0.1.jar

RUN apt-get update \
    && apt-get install -y --no-install-recommends libjemalloc1 \
    && apt-get install net-tools \
    && apt-get install -y cron \
    && rm -rf /var/lib/apt/lists/*

# copy necessary files for backups to work
COPY backup/ /backup

# copy necessary files for cassandra repairs to work
COPY repair/ /repair

# copy script used to setup cron job
COPY setup_crone_job.sh /setup_crone_job.sh

# enable cron logging
RUN touch /var/log/cron.log

# copy some script to run spark
COPY ["scripts/start-master.sh", "scripts/start-worker.sh", "scripts/spark-shell.sh", "scripts/spark-defaults.conf", "./"]
COPY conf/log4j-server.properties /app/log4j-server.properties
COPY conf/spark-env.sh /usr/local/spark/conf/spark-env.sh

# configure spark
ENV SPARK_HOME=/usr/local/spark SPARK_MASTER_OPTS="-Dspark.driver.port=7001 -Dspark.fileserver.port=7002 -Dspark.broadcast.port=7003 -Dspark.replClassServer.port=7004 -Dspark.blockManager.port=7005 -Dspark.executor.port=7006 -Dspark.ui.port=4040 -Dspark.broadcast.factory=org.apache.spark.broadcast.HttpBroadcastFactory" SPARK_WORKER_OPTS=$SPARK_MASTER_OPTS \
SPARK_MASTER_PORT=7077 SPARK_MASTER_WEBUI_PORT=8080 SPARK_WORKER_PORT=8888 SPARK_WORKER_WEBUI_PORT=8081 CASSANDRA_CONFIG=/etc/cassandra

# listen to all rpc
RUN 	sed -ri 's/^(rpc_address:).*/\1 0.0.0.0/;' "$CASSANDRA_CONFIG/cassandra.yaml" && \
	sed -ri '/authenticator: AllowAllAuthenticator/c\authenticator: PasswordAuthenticator' "$CASSANDRA_CONFIG/cassandra.yaml" && \
	sed -ri '/authorizer: AllowAllAuthorizer/c\authorizer: CassandraAuthorizer' "$CASSANDRA_CONFIG/cassandra.yaml" && \
	sed -ri '/endpoint_snitch: SimpleSnitch/c\endpoint_snitch: GossipingPropertyFileSnitch' "$CASSANDRA_CONFIG/cassandra.yaml" && \
	sed -i -e '$a\JVM_OPTS="$JVM_OPTS -Dcassandra.metricsReporterConfigFile=metrics_reporter.yaml"' "$CASSANDRA_CONFIG/cassandra-env.sh" && \
	sed -i '/# set jvm HeapDumpPath with CASSANDRA_HEAPDUMP_DIR/a CASSANDRA_HEAPDUMP_DIR="/var/log/cassandra"' "$CASSANDRA_CONFIG/cassandra-env.sh"

COPY cassandra-configurator.sh /cassandra-configurator.sh
COPY update_users.sh /update_users.sh
COPY conf/metrics_reporter.yaml $CASSANDRA_CONFIG/metrics_reporter.yaml

ENTRYPOINT ["/cassandra-configurator.sh"]

### Spark
# 4040: spark ui
# 7001: spark driver
# 7002: spark fileserver
# 7003: spark broadcast
# 7004: spark replClassServer
# 7005: spark blockManager
# 7006: spark executor
# 7077: spark master
# 8080: spark master ui
# 8081: spark worker ui
# 8888: spark worker
### Cassandra
# 7000: C* intra-node communication
# 7199: C* JMX
# 9042: C* CQL
# 9160: C* thrift service
EXPOSE 4040 7000 7001 7002 7003 7004 7005 7006 7077 7199 8080 8081 8888 9042 9160

CMD ["cassandra"]
