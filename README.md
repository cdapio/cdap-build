# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out CDAP, CDAP Security Extensions,
and Cask Hydrator Plugins. The external application
artifact repositories are located under `app-artifacts`, while
security extensions are located under `security-extensions`, so
CDAP should be built using
`-Dadditional.artifacts.dir=$(pwd)/app-artifacts -Dsecurity.extensions.dir=$(pwd)/security-extensions`
to include the additional projects in the CDAP Master packages.

## Submodules and Git

This repository uses Git submodules to provide links to other
repositories. Cloning this repository with `--recursive` will
automatically initialize and checkout the additional repositories.
These additional repositories are configured to track the correct
remote branches for a given CDAP release. This repository will have
the correct Git references stored for a particular tag. Checking
out a tag to your working directory will update the submodule Git
references to the ones used to build that tag.

If you cloned without using `--recursive`, you will need to
initialize and checkout the submodules:

```bash
git submodule init
git submodule update
```

Starting with Git 1.8, it is possible to track remote branches
in Git submodules. These branches have already been configured
for each submodule, and the submodules can be updated to the
head of that branch by appending `--remote` to the update command:

```bash
git submodule update --remote
```

## Building a CDAP release

### Compiling/Installing Apache Sentry 1.7.0

The CDAP Security Extensions require you to have Apache Sentry 1.7.0
JARs in your local Maven repository. These JARs are not available from
Maven Central, so you may need to compile them. The correct branch
for Sentry is included as a submodule under `apache-sentry` to make
compilation easy.

```bash
mvn clean install -DskipTests -f apache-sentry
```

### Installing CDAP API JARs

Compiling the artifacts requires first building and installing the
CDAP API JARs into your local Maven repository.

```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api -P templates
mvn install -DskipTests -B -am -f cdap/cdap-app-templates -P templates
```

### Compiling CDAP, including external artifacts and security extensions (example)

```bash
mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb,tgz,unit-tests \
 -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.useagent=false \
 -Dadditional.artifacts.dir=$(pwd)/app-artifacts \
 -Dsecurity.extensions.dir=$(pwd)/security-extensions
```
