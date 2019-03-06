# CDAP Build repository

This repository is used for building a complete CDAP release.

This checks out CDAP, Cask Tracker, CDAP Navigator, CDAP Security
Extensions, and Cask Hydrator Plugins. The external application
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

## Confluence Link for CDAP Builds / Versions and Branches.
https://guavus.atlassian.net/wiki/spaces/RAF/pages/446398514/Guavus+CDAP+RAF+Releases

## Guavus steps to BUILD CDAP RPMs

Run the following commands to successfully build the CDAP RPMs

```bash
git clone --recursive -b build_guavus_5.1 https://github.com/Guavus/cdap-build.git
```

Run the above command to clone the guavus cdap branch name "build_guavus".
Once the above command succeeded move inside the cdap-build folder.

```bash
cd cdap-build
```

Run the following to command to checkout specific branch for all the modules specify inside the .gitmodules file

```bash
git submodule update --remote
git submodule update --init --recursive --remote
```

After the completion of the command move to the parent directory and run the following commands in the sequence

```bash
export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m"
mvn install -DskipTests -B -am -pl cdap/cdap-api -P templates
mvn install -DskipTests -B -am -f cdap/cdap-app-templates -P templates
rm -rf cdap/cdap-security/target/*
mvn package -P examples,templates,dist,release,rpm-prepare,rpm \
-DskipTests \
-Dadditional.artifacts.dir=$(pwd)/app-artifacts \
-Dsecurity.extensions.dir=$(pwd)/security-extensions \
-DbuildNumber=1
```

## To Upgrade version 
For all pom's inside the cdap submodule
```
grep -lr --include=pom.xml "5.1.201" * | xargs sed -i -e 's/5.1.201/5.1.202/g'
```
Above command is to upgrade from version 5.1.201 to 5.1.202

In All submodules change the version of variable cdap.version inside the pom.xml to the version we are upgrading
