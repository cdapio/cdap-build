#!/usr/bin/env bash
# Copyright 2026 Cask Data, Inc.
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
#
# Unpacks the Apache Hadoop distribution used by CDAP images and applies the
# CDAP-specific runtime adjustments. Inputs are local files so that both the
# GitHub and the Cloud Data Fusion builds can fetch artifacts their own way.
set -euo pipefail

: "${HADOOP_VERSION:?}"          # e.g. 3.4.3
: "${HADOOP_TARBALL:?}"          # path to hadoop-${HADOOP_VERSION}.tar.gz
: "${HADOOP_TARBALL_SHA512:?}"   # expected SHA512 of the tarball
: "${AWS_SDK_JAR:?}"             # path to hadoop-aws-sdk-<ver>.jar
: "${ZOOKEEPER_JAR:?}"           # path to zookeeper-3.4.5.jar
: "${JLINE_JAR:?}"               # path to jline-3.30.17.jar
LICENSES_DIR="${LICENSES_DIR:-/opt/cdap/LICENSES}"
H="/opt/hadoop/hadoop-${HADOOP_VERSION}"

echo "${HADOOP_TARBALL_SHA512}  ${HADOOP_TARBALL}" | sha512sum -c -
mkdir -p /opt/hadoop
tar -xzf "${HADOOP_TARBALL}" -C /opt/hadoop

# AWS SDK v2 for hadoop-aws (S3A). The Apache tarball does not ship one.
cp "${AWS_SDK_JAR}" "${H}/share/hadoop/common/lib/"

# Twill needs ZooKeeper 3.4.x client wire compatibility.
for d in common hdfs; do
  rm -f "${H}/share/hadoop/${d}/lib/zookeeper-"*.jar "${H}/share/hadoop/${d}/lib/zookeeper-jute-"*.jar
  cp "${ZOOKEEPER_JAR}" "${H}/share/hadoop/${d}/lib/"
done

# JLine 3.9.0 is flagged; replace it and drop archives that embed it.
rm -f "${H}/share/hadoop/yarn/lib/jline-3.9.0.jar"
cp "${JLINE_JAR}" "${H}/share/hadoop/yarn/lib/"
rm -f "${H}/share/hadoop/yarn/hadoop-yarn-applications-catalog-webapp-${HADOOP_VERSION}.war" \
      "${H}/share/hadoop/client/hadoop-client-runtime-${HADOOP_VERSION}.jar" \
      "${H}/share/hadoop/client/hadoop-client-minicluster-${HADOOP_VERSION}.jar"

# Remove paranamer-2.3.jar if present (carried over from the 3.3.6 image cleanup).
find "${H}" -name 'paranamer-2.3.jar' -delete

# Licenses.
mkdir -p "${LICENSES_DIR}/hadoop-${HADOOP_VERSION}"
cp -r "${H}"/*.txt "${H}/LICENSE-binary" "${H}/NOTICE-binary" "${H}/licenses-binary" "${LICENSES_DIR}/hadoop-${HADOOP_VERSION}/"

# Self-checks: fail the image build loudly if the layout is not what we expect.
test -f "${H}/share/hadoop/common/hadoop-common-${HADOOP_VERSION}.jar"
test -f "${H}/share/hadoop/common/lib/hadoop-aws-${HADOOP_VERSION}.jar"
test -f "${H}/share/hadoop/common/lib/commons-configuration2-2.10.1.jar"
test -f "${H}/share/hadoop/hdfs/lib/commons-configuration2-2.10.1.jar"
test -f "${H}/share/hadoop/common/lib/$(basename "${AWS_SDK_JAR}")"
test -f "${H}/share/hadoop/common/lib/$(basename "${ZOOKEEPER_JAR}")"
test -f "${H}/share/hadoop/hdfs/lib/$(basename "${ZOOKEEPER_JAR}")"
test -f "${H}/share/hadoop/yarn/lib/$(basename "${JLINE_JAR}")"
test -z "$(find "${H}" \( -name 'zookeeper-3.8*.jar' -o -name 'jline-3.9.0.jar' -o -name 'htrace-core-3.1.0*.jar' -o -name 'paranamer-2.3.jar' \))"
echo "prepare_hadoop.sh: Hadoop ${HADOOP_VERSION} ready under ${H}"
