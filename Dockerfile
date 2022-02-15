#
# Copyright © 2016-2021 Cask Data, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

FROM gcr.io/cdapio/cdap-build:latest AS build
ENV DIR /cdap/build
ENV MAVEN_OPTS -Xmx2048m -Dhttp.keepAlive=false
ENV NODE_OPTIONS --max-old-space-size=8192
WORKDIR $DIR/
COPY . $DIR/
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
  apt-get update && \
  apt-get -y install nodejs && \
  mvn install -f cdap -B -V -Ddocker.skip=true -DskipTests -P templates,!unit-tests && \
  mvn install -B -V -Ddocker.skip=true -DskipTests -P templates,dist,k8s,!unit-tests \
    -Dadditional.artifacts.dir=$DIR/app-artifacts \
    -Dsecurity.extensions.dir=$DIR/security-extensions \
    -Dui.build.name=cdap-non-optimized-full-build

FROM openjdk:8-jdk AS run
WORKDIR /
COPY --from=build /cdap/build/cdap/cdap-master/target/stage-packaging/opt/cdap/master /opt/cdap/master
COPY --from=build /cdap/build/cdap/cdap-ui/target/stage-packaging/opt/cdap/ui /opt/cdap/ui
COPY --from=build /cdap/build/cdap/cdap-distributions/src/etc/cdap/conf.dist/logback*.xml /opt/cdap/master/conf/
COPY metrics-writer-extension/target/libexec/* /opt/cdap/master/ext/metricswriters/google_cloud_monitoring_writer/

RUN apt-get update && \
  apt-get -y install libxml2-utils && \
  mkdir -p /opt/spark && \
  mkdir -p /opt/hadoop && \
  mkdir -p /opt/cdap/master/ext/jdbc/postgresql && \
  curl -L -o /opt/hadoop/hadoop-2.9.2.tar.gz https://archive.apache.org/dist/hadoop/common/hadoop-2.9.2/hadoop-2.9.2.tar.gz && \
  curl -L -o /opt/spark/spark-3.1.1-bin-without-hadoop.tgz https://archive.apache.org/dist/spark/spark-3.1.1/spark-3.1.1-bin-without-hadoop.tgz && \
  curl -L -o /opt/cdap/master/lib/gcs-connector-hadoop2-latest.jar https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.2.5.jar https://jdbc.postgresql.org/download/postgresql-42.2.5.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgres-socket-factory-1.0.12-jar-with-dependencies.jar https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/releases/download/v1.0.12/postgres-socket-factory-1.0.12-jar-with-dependencies.jar && \
  tar -xzf /opt/hadoop/hadoop-2.9.2.tar.gz -C /opt/hadoop && \
  curl -L -o /opt/hadoop/hadoop-2.9.2/share/hadoop/common/lib/hadoop-aws-2.9.2.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/2.9.2/hadoop-aws-2.9.2.jar && \
  curl -L -o /opt/hadoop/hadoop-2.9.2/share/hadoop/common/lib/aws-java-sdk-bundle-1.11.199.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.199/aws-java-sdk-bundle-1.11.199.jar && \
  tar -xzf /opt/spark/spark-3.1.1-bin-without-hadoop.tgz -C /opt/spark && \
  mv /opt/cdap/ui/server_dist/index.js /opt/cdap/ui/ && \
  mv /opt/cdap/ui/server_dist/graphql /opt/cdap/ui/ && \
  mv /opt/cdap/ui/server_dist/server /opt/cdap/ui/ && \
  find /opt/hadoop -name 'paranamer-2.3.jar' -exec rm {} + && \
  find /opt/cdap/ui/ -maxdepth 1 -mindepth 1 -exec ln -s {} /opt/cdap/ \;

ENV CLASSPATH=/etc/cdap/conf:/etc/cdap/security:/etc/hadoop/conf
ENV HADOOP_HOME=/opt/hadoop/hadoop-2.9.2
ENV SPARK_HOME=/opt/spark/spark-3.1.1-bin-without-hadoop
ENV SPARK_COMPAT=spark2_2.11
ENV HBASE_VERSION=1.2

RUN groupadd -g 1000 cdap
RUN useradd -m -u 1000 -g 1000 cdap
RUN mkdir /data
RUN chown 1000:1000 /data
RUN chmod 766 /data
ENTRYPOINT ["/opt/cdap/master/bin/cdap", "run"]
