# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out CDAP, Cask Tracker, CDAP Navigator, and Cask
Hydrator Plugins. The external repositories are located under
`app-artifacts`, so CDAP should be built using
`-Dadditional.artifacts.dir=$(pwd)/app-artifacts` to include the
additional projects in the CDAP Master packages. Compiling the
artifacts requires first building and installing the CDAP API JARs into
your local Maven repository.

## Installing CDAP API JARs:
```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api -P templates
mvn install -DskipTests -B -am -f cdap/cdap-app-templates -P templates
```

## Compiling CDAP + Cask Tracker + CDAP Navigator + Cask Hydrator Plugins (example)
```bash
mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb,tgz,unit-tests \
 -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.useagent=false \
 -Dadditional.artifacts.dir=$(pwd)/app-artifacts
```
