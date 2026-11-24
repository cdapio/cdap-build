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
# Unpacks the Apache Spark distribution used by CDAP images and applies the
# jar overrides from jar-overrides.txt. Inputs are local files so that both the
# GitHub and the Cloud Data Fusion builds can fetch artifacts their own way.
set -euo pipefail

: "${SPARK_VERSION:?}"           # e.g. 3.5.8
: "${SPARK_TARBALL:?}"           # path to spark-${SPARK_VERSION}-bin-without-hadoop.tgz
: "${JAR_OVERRIDES:?}"           # path to jar-overrides.txt
: "${JAR_SOURCE:?}"              # repository base URL or local directory, see jar_overrides.sh
SPARK_TARBALL_SHA512="${SPARK_TARBALL_SHA512:-}"  # optional expected SHA512 of the tarball
LICENSES_DIR="${LICENSES_DIR:-/opt/cdap/LICENSES}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="spark/spark-${SPARK_VERSION}-bin-without-hadoop"
S="/opt/${DIST}"

if [[ -n "${SPARK_TARBALL_SHA512}" ]]; then
  echo "${SPARK_TARBALL_SHA512}  ${SPARK_TARBALL}" | sha512sum -c -
fi
mkdir -p /opt/spark
tar -xzf "${SPARK_TARBALL}" -C /opt/spark

# Shared jar replacements, additions and deletions.
JAR_SOURCE="${JAR_SOURCE}" bash "${SCRIPT_DIR}/jar_overrides.sh" apply "${JAR_OVERRIDES}" "${DIST}"

# Licenses.
mkdir -p "${LICENSES_DIR}/spark-${SPARK_VERSION}-bin-without-hadoop"
cp "${S}/LICENSE" "${S}/NOTICE" "${LICENSES_DIR}/spark-${SPARK_VERSION}-bin-without-hadoop/"

# Self-checks: fail the image build loudly if the layout is not what we expect.
test -x "${S}/bin/spark-submit"
test -f "${S}/jars/spark-core_2.12-${SPARK_VERSION}.jar"
test -f "${LICENSES_DIR}/spark-${SPARK_VERSION}-bin-without-hadoop/LICENSE"
echo "prepare_spark.sh: Spark ${SPARK_VERSION} ready under ${S}"
