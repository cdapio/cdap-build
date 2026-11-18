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

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl ca-certificates procps libxml2-utils zip && \
  apt-get upgrade -y && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /opt/spark && \
  mkdir -p /opt/hadoop && \
  mkdir -p /opt/cdap/master/ext/jdbc/postgresql && \
  curl -fSL -o /opt/hadoop/hadoop-3.4.3.tar.gz https://archive.apache.org/dist/hadoop/common/hadoop-3.4.3/hadoop-3.4.3.tar.gz && \
  curl -fSL -o /opt/spark/spark-3.3.2-bin-without-hadoop.tgz https://archive.apache.org/dist/spark/spark-3.3.2/spark-3.3.2-bin-without-hadoop.tgz && \
  curl -fSL -o /opt/cdap/master/lib/gcs-connector-hadoop3-2.2.21.jar https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-2.2.21.jar && \
  curl -fSL -o /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.7.11.jar https://jdbc.postgresql.org/download/postgresql-42.7.11.jar && \
  curl -fSL -o /opt/cdap/master/ext/jdbc/postgresql/postgres-socket-factory-1.0.12-jar-with-dependencies.jar https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/releases/download/v1.0.12/postgres-socket-factory-1.0.12-jar-with-dependencies.jar && \
  tar -xzf /opt/hadoop/hadoop-3.4.3.tar.gz -C /opt/hadoop && rm /opt/hadoop/hadoop-3.4.3.tar.gz && \
  tar -xzf /opt/spark/spark-3.3.2-bin-without-hadoop.tgz -C /opt/spark && rm /opt/spark/spark-3.3.2-bin-without-hadoop.tgz && \
  # Align Hadoop/Spark jar overrides with the Cloud Data Fusion image.
  curl -fSL -o /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/bundle-2.59.2.jar https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.59.2/bundle-2.59.2.jar && \
  zip -qd /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/bundle-2.59.2.jar \
    'software/amazon/awssdk/services/*' \
    'META-INF/maven/software.amazon.awssdk/*' \
    'META-INF/services/software.amazon.awssdk.core.warmup.SdkWarmUpProvider' \
    'META-INF/software.amazon.awssdk/*' \
    -x 'software/amazon/awssdk/services/s3/*' \
       'software/amazon/awssdk/services/s3control/*' \
       'software/amazon/awssdk/services/sts/*' \
       'software/amazon/awssdk/services/iam/*' \
       'software/amazon/awssdk/services/kms/*' \
       'software/amazon/awssdk/services/sso/*' \
       'software/amazon/awssdk/services/ssooidc/*' \
       'software/amazon/awssdk/services/dynamodb/*' \
       'META-INF/maven/software.amazon.awssdk/bundle/*' \
       'META-INF/maven/software.amazon.awssdk/s3/*' \
       'META-INF/maven/software.amazon.awssdk/s3control/*' \
       'META-INF/maven/software.amazon.awssdk/sts/*' \
       'META-INF/maven/software.amazon.awssdk/iam/*' \
       'META-INF/maven/software.amazon.awssdk/kms/*' \
       'META-INF/maven/software.amazon.awssdk/sso/*' \
       'META-INF/maven/software.amazon.awssdk/ssooidc/*' \
       'META-INF/maven/software.amazon.awssdk/dynamodb/*' \
       'META-INF/software.amazon.awssdk/bundle/*' \
       'META-INF/software.amazon.awssdk/s3/*' \
       'META-INF/software.amazon.awssdk/s3control/*' \
       'META-INF/software.amazon.awssdk/sts/*' \
       'META-INF/software.amazon.awssdk/iam/*' \
       'META-INF/software.amazon.awssdk/kms/*' \
       'META-INF/software.amazon.awssdk/sso/*' \
       'META-INF/software.amazon.awssdk/ssooidc/*' \
       'META-INF/software.amazon.awssdk/dynamodb/*' && \
  curl -fSL -o /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/zookeeper-3.4.5.jar https://repo1.maven.org/maven2/org/apache/zookeeper/zookeeper/3.4.5/zookeeper-3.4.5.jar && \
  curl -fSL -o /opt/spark/spark-3.3.2-bin-without-hadoop/jars/avro-1.11.0.jar https://repo1.maven.org/maven2/org/apache/avro/avro/1.11.4/avro-1.11.4.jar && \
  cp /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/zookeeper-3.4.5.jar /opt/hadoop/hadoop-3.4.3/share/hadoop/hdfs/lib/zookeeper-3.4.5.jar && \
  rm -f /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/zookeeper-3.8.4.jar /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/zookeeper-jute-3.8.4.jar && \
  rm -f /opt/hadoop/hadoop-3.4.3/share/hadoop/hdfs/lib/zookeeper-3.8.4.jar /opt/hadoop/hadoop-3.4.3/share/hadoop/hdfs/lib/zookeeper-jute-3.8.4.jar && \
  # Upgrade JLine to 3.30.17 in YARN and remove unused Hadoop archives bundling JLine 3.9.0 and ZooKeeper 3.8.4.
  rm -f /opt/hadoop/hadoop-3.4.3/share/hadoop/yarn/lib/jline-3.9.0.jar \
        /opt/hadoop/hadoop-3.4.3/share/hadoop/yarn/hadoop-yarn-applications-catalog-webapp-3.4.3.war \
        /opt/hadoop/hadoop-3.4.3/share/hadoop/client/hadoop-client-runtime-3.4.3.jar \
        /opt/hadoop/hadoop-3.4.3/share/hadoop/client/hadoop-client-minicluster-3.4.3.jar && \
  curl -fsSL -o /opt/hadoop/hadoop-3.4.3/share/hadoop/yarn/lib/jline-3.30.17.jar https://repo1.maven.org/maven2/org/jline/jline/3.30.17/jline-3.30.17.jar && \
  # Align CDAP master lib jars that precede HADOOP_CLASSPATH with Hadoop 3.4.3 versions.
  rm -f /opt/cdap/master/lib/commons-cli.commons-cli-1.2.jar /opt/cdap/master/lib/dnsjava.dnsjava-2.1.7.jar && \
  cp /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/commons-cli-1.9.0.jar /opt/cdap/master/lib/commons-cli-1.9.0.jar && \
  cp /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/dnsjava-3.6.1.jar /opt/cdap/master/lib/dnsjava-3.6.1.jar && \
  # Copy downloaded JAR licenses to COPYRIGHT folder
  rm -rf /opt/cdap/LICENSES/commons-cli@1.2 && \
  mkdir /opt/cdap/LICENSES/hadoop-3.4.3 && cp /opt/hadoop/hadoop-3.4.3/*.txt /opt/hadoop/hadoop-3.4.3/LICENSE-binary /opt/hadoop/hadoop-3.4.3/NOTICE-binary /opt/cdap/LICENSES/hadoop-3.4.3 && \
  mkdir /opt/cdap/LICENSES/spark-3.3.2-bin-without-hadoop && cp /opt/spark/spark-3.3.2-bin-without-hadoop/LICENSE /opt/cdap/LICENSES/spark-3.3.2-bin-without-hadoop && cp /opt/spark/spark-3.3.2-bin-without-hadoop/NOTICE /opt/cdap/LICENSES/spark-3.3.2-bin-without-hadoop && \
  mkdir /opt/cdap/LICENSES/gcs-connector-hadoop3-2.2.21 && curl -fSL -o /opt/cdap/LICENSES/gcs-connector-hadoop3-2.2.21/LICENSE https://raw.githubusercontent.com/GoogleCloudDataproc/hadoop-connectors/v2.2.21/LICENSE && \
  mkdir /opt/cdap/LICENSES/postgresql-42.7.11 && jar xvf /opt/cdap/master/ext/jdbc/postgresql/postgresql-42.7.11.jar META-INF/LICENSE && cp ./META-INF/LICENSE /opt/cdap/LICENSES/postgresql-42.7.11 && rm -r ./META-INF && \
  mkdir /opt/cdap/LICENSES/postgres-socket-factory-1.0.12-jar-with-dependencies && curl -fSL -o /opt/cdap/LICENSES/postgres-socket-factory-1.0.12-jar-with-dependencies/LICENSE https://raw.githubusercontent.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/v1.0.12/LICENSE && \
  mkdir /opt/cdap/LICENSES/hadoop-aws-3.4.3 && jar xvf /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/hadoop-aws-3.4.3.jar META-INF/LICENSE META-INF/LICENSE.txt && cp ./META-INF/LICENSE* /opt/cdap/LICENSES/hadoop-aws-3.4.3 && rm -r ./META-INF && \
  mkdir /opt/cdap/LICENSES/aws-sdk-java-bundle-2.59.2 && jar xvf /opt/hadoop/hadoop-3.4.3/share/hadoop/common/lib/bundle-2.59.2.jar META-INF/LICENSE META-INF/LICENSE.txt && cp ./META-INF/LICENSE* /opt/cdap/LICENSES/aws-sdk-java-bundle-2.59.2 && rm -r ./META-INF && \
  mkdir -p /opt/cdap/LICENSES/jline-3.30.17 && curl -fsSL -o /opt/cdap/LICENSES/jline-3.30.17/LICENSE.txt https://raw.githubusercontent.com/jline/jline3/jline-3.30.17/LICENSE.txt && \
  mkdir -p /opt/cdap/LICENSES/commons-cli-1.9.0 && jar xvf /opt/cdap/master/lib/commons-cli-1.9.0.jar META-INF/LICENSE.txt META-INF/NOTICE.txt && cp ./META-INF/LICENSE.txt ./META-INF/NOTICE.txt /opt/cdap/LICENSES/commons-cli-1.9.0 && rm -r ./META-INF && \
  mkdir -p /opt/cdap/LICENSES/dnsjava-3.6.1 && jar xvf /opt/cdap/master/lib/dnsjava-3.6.1.jar META-INF/LICENSE && cp ./META-INF/LICENSE /opt/cdap/LICENSES/dnsjava-3.6.1 && rm -r ./META-INF && \
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
