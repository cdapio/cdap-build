# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out CDAP, Cask Tracker, CDAP Navigator, and Hydrator
Plugins. The external repositories are located under
`app-artifacts`, so CDAP should be built using
`-Dadditional.artifacts.dir=$(pwd)/app-artifacts` to include the
additional projects in the CDAP Master packages. Compiling the
artifacts requires first building and installing the CDAP API JARs into
your local Maven repository.

## Installing CDAP API JARs:
```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api,cdap/cdap-app-templates/cdap-etl/cdap-etl-api -P templates
```

## Compiling CDAP + Cask Tracker + CDAP Navigator + Hydrator Plugins (example)
```bash
mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb,tgz,unit-tests \
 -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.useagent=false \
 -Dadditional.artifacts.dir=$(pwd)/app-artifacts
```
