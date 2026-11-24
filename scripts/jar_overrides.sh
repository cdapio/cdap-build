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
# Applies the jar overrides listed in jar-overrides.txt to one unpacked
# distribution (Hadoop or Spark) under /opt. Called by prepare_hadoop.sh and
# prepare_spark.sh so that the OSS CDAP image and the Cloud Data Fusion images
# replace, add and delete exactly the same third-party jars.
#
# Usage:
#   jar_overrides.sh apply <manifest> <dist>
#   jar_overrides.sh list  <manifest> [<dist>...]
#
# <dist> is the distribution directory relative to /opt, for example
# hadoop/hadoop-3.4.3 or spark/spark-3.5.8-bin-without-hadoop. Only manifest
# entries whose directories are inside <dist> are applied, so one manifest can
# carry entries for several Hadoop and Spark versions.
#
# "apply" needs JAR_SOURCE, which is either a repository base URL in Maven
# layout (for example https://repo1.maven.org/maven2) or a local directory that
# holds the jars either in Maven layout or flat by file name. The script never
# picks a repository on its own. "list" prints the Maven paths of every jar the
# entries for the given distributions add, so builds can pre-fetch or cache them.
#
# Manifest format, one entry per line; comments only on their own lines:
#   <dirs relative to /opt> | <old file glob> | <Maven path of new jar>
#     Replace: every dir in which <old file glob> matches loses the matches and
#     gets the new jar. Fails if the glob matches in none of the dirs.
#   +<dirs relative to /opt> | - | <Maven path of new jar>
#     Add the new jar to every dir.
#   <dirs relative to /opt> | <old file glob> | -
#     Delete: remove the matches (files or whole directories). Fails if the
#     glob matches in none of the dirs.
#   !<dist> | <extended regex>
#     Guard: after all entries are applied, fail if any jar or war file name
#     under <dist> matches the regex (an old version is still present).
set -euo pipefail

OPT_ROOT="${OPT_ROOT:-/opt}"

die() {
  echo "jar_overrides.sh: $*" >&2
  exit 1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# Prints the manifest entries without comments and blank lines.
entries() {
  sed -e 's/^[[:space:]]*//' -e '/^#/d' -e '/^$/d' "$1"
}

# Returns 0 if every dir in the space separated list $1 is inside dist $2 and
# 1 if none is. An entry that spans distributions is a manifest error.
in_dist() {
  local d inside=0 outside=0
  for d in $1; do
    case "${d}" in
      "$2" | "$2"/*) inside=1 ;;
      *) outside=1 ;;
    esac
  done
  [[ "${inside}" -eq 1 && "${outside}" -eq 1 ]] && die "entry spans distributions: $1"
  [[ "${inside}" -eq 1 ]]
}

fetch() {
  local path="$1" dest="$2" name
  name="$(basename "${path}")"
  case "${JAR_SOURCE}" in
    http://* | https://*)
      curl -fsSL -o "${dest}/${name}" "${JAR_SOURCE%/}/${path}" || die "download failed: ${JAR_SOURCE%/}/${path}"
      ;;
    *)
      if [[ -f "${JAR_SOURCE}/${path}" ]]; then
        cp "${JAR_SOURCE}/${path}" "${dest}/${name}"
      elif [[ -f "${JAR_SOURCE}/${name}" ]]; then
        cp "${JAR_SOURCE}/${name}" "${dest}/${name}"
      else
        die "${name} not found in ${JAR_SOURCE}"
      fi
      ;;
  esac
}

apply() {
  local manifest="$1" dist="$2" line dirs old new add d hit m
  local -a matches
  : "${JAR_SOURCE:?JAR_SOURCE must be a repository base URL or a local directory}"
  [[ -d "${OPT_ROOT}/${dist}" ]] || die "${OPT_ROOT}/${dist} does not exist"
  local -a guards=()
  while IFS= read -r line; do
    if [[ "${line}" == '!'* ]]; then
      IFS='|' read -r d old <<<"${line#!}"
      [[ "$(trim "${d}")" == "${dist}" ]] && guards+=("$(trim "${old}")")
      continue
    fi
    IFS='|' read -r dirs old new <<<"${line}"
    dirs="$(trim "${dirs}")"
    old="$(trim "${old}")"
    new="$(trim "${new}")"
    add=false
    if [[ "${dirs}" == '+'* ]]; then
      add=true
      dirs="$(trim "${dirs#+}")"
    fi
    [[ -n "${dirs}" && -n "${old}" && -n "${new}" ]] || die "malformed entry: ${line}"
    in_dist "${dirs}" "${dist}" || continue
    hit=0
    for d in ${dirs}; do
      d="${OPT_ROOT}/${d}"
      if ${add}; then
        [[ -d "${d}" ]] || die "add target ${d} does not exist"
        fetch "${new}" "${d}"
        echo "jar_overrides.sh: + ${d}/$(basename "${new}")"
        hit=1
        continue
      fi
      shopt -s nullglob
      # shellcheck disable=SC2206 # the glob must expand here
      matches=("${d}"/${old})
      shopt -u nullglob
      # A name without glob characters is kept even if it does not exist.
      [[ ${#matches[@]} -eq 1 && ! -e "${matches[0]}" ]] && matches=()
      [[ ${#matches[@]} -gt 0 ]] || continue
      hit=1
      for m in "${matches[@]}"; do
        rm -rf "${m}"
        echo "jar_overrides.sh: - ${m}"
      done
      if [[ "${new}" != "-" ]]; then
        fetch "${new}" "${d}"
        echo "jar_overrides.sh: + ${d}/$(basename "${new}")"
      fi
    done
    [[ "${hit}" -eq 1 ]] || die "override matched nothing: ${line}"
  done < <(entries "${manifest}")

  local g found
  for g in ${guards[@]+"${guards[@]}"}; do
    found="$(find "${OPT_ROOT}/${dist}" \( -name '*.jar' -o -name '*.war' \) -printf '%f\n' | { grep -E -- "${g}" || true; })"
    [[ -z "${found}" ]] || die "old jar version still present (guard ${g}): ${found//$'\n'/ }"
  done
  echo "jar_overrides.sh: ${dist} done (${#guards[@]} guard(s) passed)"
}

list() {
  local manifest="$1" line dirs old new dist
  shift
  while IFS= read -r line; do
    [[ "${line}" == '!'* ]] && continue
    IFS='|' read -r dirs old new <<<"${line}"
    dirs="$(trim "${dirs#+}")"
    new="$(trim "${new}")"
    [[ "${new}" == "-" ]] && continue
    if [[ $# -eq 0 ]]; then
      echo "${new}"
      continue
    fi
    for dist in "$@"; do
      if in_dist "${dirs}" "${dist}"; then
        echo "${new}"
        break
      fi
    done
  done < <(entries "${manifest}") | sort -u
}

case "${1:-}" in
  apply)
    [[ $# -eq 3 ]] || die "usage: $0 apply <manifest> <dist>"
    apply "$2" "$3"
    ;;
  list)
    [[ $# -ge 2 ]] || die "usage: $0 list <manifest> [<dist>...]"
    list "${@:2}"
    ;;
  *)
    die "usage: $0 apply <manifest> <dist> | list <manifest> [<dist>...]"
    ;;
esac
