# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out CDAP, Cask Tracker, CDAP Navigator, CDAP Security
Extensions, and Cask Hydrator Plugins. The external application
artifact repositories are located under `app-artifacts`, while
security extensions are located under `security-extensions`, so
CDAP should be built using
`-Dadditional.artifacts.dir=$(pwd)/app-artifacts -Dsecurity.extensions.dir=$(pwd)/security-extensions`
to include the additional projects in the CDAP Master packages.

## Compiling/Installing Apache Sentry 1.7.0

The CDAP Security Extensions requires you to have Apache Sentry 1.7.0
JARs in your local Maven repository. These JARs are not available from
Maven Central, so you may need to compile them. The correct branch
for Sentry is included as a submodule under `apache-sentry` to make
compilation easy.

```bash
git submodule init
git submodule update
cd apache-sentry
mvn clean install -BskipTests
cd ..
```

## Installing CDAP API JARs

Compiling the artifacts requires first building and installing the
CDAP API JARs into your local Maven repository.

```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api,cdap/cdap-app-templates -P templates
```

## Compiling CDAP + Cask Tracker + CDAP Navigator + Cask Hydrator Plugins (example)
```bash
mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb,tgz,unit-tests \
 -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.useagent=false \
 -Dadditional.artifacts.dir=$(pwd)/app-artifacts \
 -Dsecurity.extensions.dir=$(pwd)/security-extensions
```
