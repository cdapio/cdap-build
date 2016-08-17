# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out both CDAP and Hydrator Plugins. The Hydrator Plugins
are located under `app-artifacts`, so CDAP should be built using
`-Dadditional.artifacts.dir=$(pwd)/app-artifacts` to include the
Hydrator Plugins in the CDAP Master packages. Compiling the Hydrator
Plugins requires first building and installing the CDAP API JARs into
your local Maven repository.

## Installing CDAP API JARs:
```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api,cdap/cdap-app-templates -P templates
```

## Compiling CDAP + Hydrator Plugins (example)
```bash
mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb,tgz,unit-tests \
 -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.useagent=false \
 -Dadditional.artifacts.dir=$(pwd)/app-artifacts
```
