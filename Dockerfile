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
ENV MAVEN_OPTS -Xmx4096m -Dhttp.keepAlive=false
ENV NODE_OPTIONS --max-old-space-size=8192
ARG EXTEND_DEFAULT_CONFIGS=false
ARG CONFIG_FILE_NAME
WORKDIR $DIR/
COPY . $DIR/
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list
RUN tar -zcvf cdap-build-sources.tar.gz --exclude='.git*' --exclude='node_modules' --exclude='target' --exclude-vcs \
        --exclude-vcs-ignores app-artifacts cdap eventwriters-extensions metricswriters-extensions security-extensions \
        Dockerfile LICENSE.txt README.md && \
    apt-get update && apt-get install -y lsb-release gnupg curl && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /tmp/nodesource.key && gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg /tmp/nodesource.key && rm /tmp/nodesource.key && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    # installation of nodejs expects /bin/bash instead of /bin/sh
    apt-get update && /bin/bash -c 'apt-get -y install nodejs' && \

    mvn install -f cdap -B -V -Ddocker.skip=true -DskipTests -P 'templates,!unit-tests' && \
    mvn install -B -V -Ddocker.skip=true -DskipTests -P 'templates,dist,k8s,!unit-tests' \
      -Dadditional.artifacts.dir="$DIR/app-artifacts" \
      -Dsecurity.extensions.dir="$DIR/security-extensions" \
      -Dmetricswriters.extensions.dir="$DIR/metricswriters-extensions" \
      -Deventwriters.extensions.dir="$DIR/eventwriters-extensions" \
      -Dextend-default-configs="$EXTEND_DEFAULT_CONFIGS" -Dconfig-path="$DIR/$CONFIG_FILE_NAME" \
      -Dui.build.name=cdap-non-optimized-full-build

FROM eclipse-temurin:11-jdk-jammy@sha256:0ab919c546b23b2da000376778ce947596d1f92d18a32fd69342743bd0e1e431 AS jdk-source

FROM debian:13-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS run
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"
COPY --from=jdk-source /opt/java/openjdk /opt/java/openjdk
WORKDIR /
COPY --from=build /cdap/build/cdap/cdap-master/target/stage-packaging/opt/cdap/master /opt/cdap/master
COPY --from=build /cdap/build/cdap/cdap-ui/target/stage-packaging/opt/cdap/ui /opt/cdap/ui
COPY --from=build /cdap/build/cdap/cdap-distributions/src/etc/cdap/conf.dist/logback*.xml /opt/cdap/master/conf/
COPY --from=build /cdap/build/cdap/cdap-distributions/src/COPYRIGHT /opt/cdap/LICENSES
COPY --from=build /cdap/build/cdap-build-sources.tar.gz /opt/cdap/cdap-build-sources.tar.gz
COPY --from=build /cdap/build/hadoop-aws-sdk/target/hadoop-aws-sdk-2.35.4.jar /tmp/h/hadoop-aws-sdk-2.35.4.jar
COPY scripts/prepare_hadoop.sh scripts/prepare_spark.sh scripts/jar_overrides.sh scripts/jar-overrides.txt /tmp/h/

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl ca-certificates procps libxml2-utils && \
  apt-get upgrade -y && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /opt/spark && \
  mkdir -p /opt/cdap/master/ext/jdbc/postgresql && \
  curl -fsSL -o /tmp/h/hadoop-3.4.3.tar.gz https://archive.apache.org/dist/hadoop/common/hadoop-3.4.3/hadoop-3.4.3.tar.gz && \
  curl -fsSL -o /tmp/h/zookeeper-3.4.5.jar https://repo1.maven.org/maven2/org/apache/zookeeper/zookeeper/3.4.5/zookeeper-3.4.5.jar && \
  curl -fsSL -o /tmp/h/jline-3.30.17.jar https://repo1.maven.org/maven2/org/jline/jline/3.30.17/jline-3.30.17.jar && \
  curl -fsSL -o /tmp/h/spark-3.3.2-bin-without-hadoop.tgz https://archive.apache.org/dist/spark/spark-3.3.2/spark-3.3.2-bin-without-hadoop.tgz && \
  export JAR_OVERRIDES=/tmp/h/jar-overrides.txt JAR_SOURCE=https://repo1.maven.org/maven2 && \
  HADOOP_VERSION=3.4.3 HADOOP_TARBALL=/tmp/h/hadoop-3.4.3.tar.gz \
  HADOOP_TARBALL_SHA512=e25be7e57b4d3c5bfe83895844321a21d6cf7331266d524d8983c27cf484e576c3d79b3b60d590f8cddecf16229d0e232de2491b1b61b362ee7d67072c7290e1 \
  AWS_SDK_JAR=/tmp/h/hadoop-aws-sdk-2.35.4.jar ZOOKEEPER_JAR=/tmp/h/zookeeper-3.4.5.jar JLINE_JAR=/tmp/h/jline-3.30.17.jar \
  bash /tmp/h/prepare_hadoop.sh && \
  SPARK_VERSION=3.3.2 SPARK_TARBALL=/tmp/h/spark-3.3.2-bin-without-hadoop.tgz \
  SPARK_TARBALL_SHA512=347fd9029128b12e7b05e9cd7948a5b571a57f16bbbbffc8ad4023b4edc0e127cffd27d66fcdbf5f926fa33362a2ae4fc0a8d59ab3abdaa1d4c4ef1e23126932 \
  bash /tmp/h/prepare_spark.sh && rm -rf /tmp/h && \
  curl -L -o /opt/cdap/master/lib/gcs-connector-hadoop3-2.2.21.jar https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-2.2.21.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.7.11.jar https://jdbc.postgresql.org/download/postgresql-42.7.11.jar && \
  curl -L -o /opt/cdap/master/ext/jdbc/postgresql/postgres-socket-factory-1.0.12-jar-with-dependencies.jar https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/releases/download/v1.0.12/postgres-socket-factory-1.0.12-jar-with-dependencies.jar && \
  curl -L -o /opt/spark/spark-3.3.2-bin-without-hadoop/jars/avro-1.11.0.jar https://repo1.maven.org/maven2/org/apache/avro/avro/1.11.4/avro-1.11.4.jar && \
  # Copy downloaded JAR licenses to COPYRIGHT folder
  mkdir /opt/cdap/LICENSES/gcs-connector-hadoop3-2.2.21 && curl -L -o /opt/cdap/LICENSES/gcs-connector-hadoop3-2.2.21/LICENSE https://raw.githubusercontent.com/GoogleCloudDataproc/hadoop-connectors/v2.2.21/LICENSE && \
  mkdir /opt/cdap/LICENSES/postgresql-42.7.11 && jar xvf /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.7.11.jar META-INF/LICENSE && cp ./META-INF/LICENSE /opt/cdap/LICENSES/postgresql-42.7.11 && rm -r ./META-INF && \
  mkdir /opt/cdap/LICENSES/postgres-socket-factory-1.0.12-jar-with-dependencies && curl -L -o /opt/cdap/LICENSES/postgres-socket-factory-1.0.12-jar-with-dependencies/LICENSE https://raw.githubusercontent.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/v1.0.12/LICENSE && \
  mv /opt/cdap/ui/server_dist/index.js /opt/cdap/ui/ && \
  mv /opt/cdap/ui/server_dist/graphql /opt/cdap/ui/ && \
  mv /opt/cdap/ui/server_dist/server /opt/cdap/ui/ && \
  find /opt/cdap/ui/ -maxdepth 1 -mindepth 1 -exec ln -s {} /opt/cdap/ \;

ENV CLASSPATH=/etc/cdap/conf:/etc/cdap/security:/etc/hadoop/conf
ENV HADOOP_HOME=/opt/hadoop/hadoop-3.4.3
ENV SPARK_HOME=/opt/spark/spark-3.3.2-bin-without-hadoop
ENV SPARK_COMPAT=spark3_2.12
ENV HBASE_VERSION=1.2

RUN groupadd -g 1000 cdap
RUN useradd -m -u 1000 -g 1000 cdap
RUN mkdir /data
RUN chown 1000:1000 /data
RUN chmod 766 /data
ENTRYPOINT ["/opt/cdap/master/bin/cdap", "run"]
