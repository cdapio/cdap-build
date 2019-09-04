#
# Copyright © 2016-2018 Cask Data, Inc.
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
ENV MAVEN_OPTS -Xmx2048m
WORKDIR $DIR/
COPY . $DIR/
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
  apt-get update && \
  apt-get -y install nodejs && \
  mvn install -f cdap -B -V -DskipTests -P templates,!unit-tests && \
  mvn install -B -V -DskipTests -P templates,dist,k8s,!unit-tests \
    -Dadditional.artifacts.dir=$DIR/app-artifacts \
    -Dsecurity.extensions.dir=$DIR/security-extensions \
    -Dui.build.name=cdap-non-optimized-full-build

FROM openjdk:8-jdk AS run
WORKDIR /
COPY --from=build /cdap/build/cdap/cdap-master/target/stage-packaging/opt/cdap/master /opt/cdap/master
COPY --from=build /cdap/build/cdap/cdap-distributions/src/etc/cdap/conf.dist/logback*.xml /opt/cdap/master/conf/

RUN apt-get update && \
  apt-get -y install libxml2-utils && \
  mkdir -p /opt/spark && \
  mkdir -p /opt/hadoop && \
  mkdir -p /opt/cdap/master/ext/jdbc/postgresql && \
  curl -L -o /opt/hadoop/hadoop-2.9.2.tar.gz https://www-us.apache.org/dist/hadoop/common/hadoop-2.9.2/hadoop-2.9.2.tar.gz && \
  curl -L -o /opt/spark/spark-2.3.3-bin-without-hadoop.tgz https://archive.apache.org/dist/spark/spark-2.3.3/spark-2.3.3-bin-without-hadoop.tgz && \
  curl -L -o /opt/cdap/master/lib/gcs-connector-hadoop2-latest.jar https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.2.5.jar https://jdbc.postgresql.org/download/postgresql-42.2.5.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgres-socket-factory-1.0.12-jar-with-dependencies.jar https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/releases/download/v1.0.12/postgres-socket-factory-1.0.12-jar-with-dependencies.jar && \
  tar -xzf /opt/hadoop/hadoop-2.9.2.tar.gz -C /opt/hadoop && \
  tar -xzf /opt/spark/spark-2.3.3-bin-without-hadoop.tgz -C /opt/spark

ENV CLASSPATH=/etc/cdap/conf:/etc/cdap/security:/etc/hadoop/conf
ENV HADOOP_HOME=/opt/hadoop/hadoop-2.9.2
ENV SPARK_HOME=/opt/spark/spark-2.3.3-bin-without-hadoop
ENV SPARK_COMPAT=spark2_2.11
ENV HBASE_VERSION=1.2
ENTRYPOINT ["/opt/cdap/master/bin/cdap", "run"]
