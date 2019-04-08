@Library('jenkins_lib')_
pipeline {
  agent {label 'slave'}
  environment { 
   	DEB_COMPONENT = 'cdap'
	DEB_ARCH = 'amd64'
	DEB_POOL = 'gvs-dev-debian/pool/c'
	ARTIFACT_SRC1 = './cdap/**/target'
	ARTIFACT_SRC2 = './cdap-ambari-service/target'
	ARTIFACT_DEST1 = 'gvs-dev-debian/pool/c'
	SONAR_PATH_CDAP = './cdap'
	SONAR_PATH_APP_ARTIFACTS_DRE = './app-artifacts/dre'
	SONAR_PATH_APP_ARTIFACTS_HYDRATOR_PLUGINS = './app-artifacts/hydrator-plugins'
	SONAR_PATH_APP_ARTIFACTS_MRDS = './app-artifacts/cdap-mrds'
	SONAR_PATH_APP_ARTIFACTS_MMDS = './app-artifacts/mmds'
	SONAR_PATH_APP_ARTIFACTS_AFE = './app-artifacts/auto-feature-engineering'
	SONAR_PATH_SECURITY_EXTN = './security-extensions/cdap-security-extn'  
	}
  stages {
    stage("Define Release version"){
      steps {
      script {
        versionDefine()
        }
      }
    }
    
	stage('Build') {
	  steps {
	    script {
		sh"""
		git clean -xfd  && \
		git submodule foreach --recursive git clean -xfd && \
		git reset --hard  && \
		git submodule foreach --recursive git reset --hard && \
		git submodule update --remote && \
		git submodule update --init --recursive --remote && \
		export MAVEN_OPTS="-Xmx3056m -XX:MaxPermSize=128m" && \
		mkdir build  && \
		cd build  && \
		cmake ..  && \
		make  && \
		cd .. && \
		cd cdap-ambari-service && \
		./build.sh && \
		cd .. && \
		cd cdap && \
		mvn clean install -DskipTests -Dcheckstyle.skip && \
		cd .. && \
		mvn clean install -DskipTests -Dcheckstyle.skip=true -B -am -pl cdap/cdap-api -P templates && \
		mvn clean install -DskipTests -Dcheckstyle.skip=true -B -am -f cdap/cdap-app-templates -P templates && \
		rm -rf ${env.WORKSPACE}/cdap/*/target/*.rpm  && \
		rm -rf ${env.WORKSPACE}/ansible_rpm/*.rpm
		"""
		    if (env.BRANCH_NAME ==~ 'release/guavus_.*') {
		    sh"""
		    mvn clean deploy -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb \
		    -DskipTests \
		    -Dcheckstyle.skip=true \
		    -Dadditional.artifacts.dir=${env.WORKSPACE}/app-artifacts \
		    -Dsecurity.extensions.dir=${env.WORKSPACE}/security-extensions -DbuildNumber=${env.RELEASE}"""
		    } 
		    else {
		    sh"""
		    mvn clean install -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb \
		    -DskipTests \
		    -Dcheckstyle.skip=true \
		    -Dadditional.artifacts.dir=${env.WORKSPACE}/app-artifacts \
		    -Dsecurity.extensions.dir=${env.WORKSPACE}/security-extensions -DbuildNumber=${env.RELEASE}"""
		    }
		sh"""
		mvn org.owasp:dependency-check-maven:check -DskipSystemScope=true \
        	-Dadditional.artifacts.dir=${env.WORKSPACE}/app-artifacts \
		"""
	}}}
	  
stage('SonarQube analysis') {
steps {
script {
/* 
cdap_sonar(Path, Name_of_Branch, Name_of_project)
The Path be a path to the folder which contains the POM file for the project/module.
*/
cdap_sonar(env.SONAR_PATH_CDAP, env.branchVersion, 'CDAP')
cdap_sonar(env.SONAR_PATH_APP_ARTIFACTS_DRE, env.branchVersion, 'DRE')
cdap_sonar(env.SONAR_PATH_APP_ARTIFACTS_HYDRATOR_PLUGINS, env.branchVersion, 'HYDRATOR-PLUGINS')
cdap_sonar(env.SONAR_PATH_APP_ARTIFACTS_MRDS, env.branchVersion, 'MRDS')
cdap_sonar(env.SONAR_PATH_APP_ARTIFACTS_MMDS, env.branchVersion, 'MMDS')
cdap_sonar(env.SONAR_PATH_APP_ARTIFACTS_AFE, env.branchVersion, 'AFE')
cdap_sonar(env.SONAR_PATH_SECURITY_EXTN, env.branchVersion, 'SECURITY-EXTENSION')
timeout(time: 2, unit: 'HOURS') {
def qg = waitForQualityGate()
if (qg.status != 'OK') {
error "Pipeline aborted due to quality gate failure: ${qg.status}"
}
}
}
}


}
	stage("ZIP PUSH"){
	  steps{
	    script{
	    tar_push ( env.buildType, '${WORKSPACE}/cdap/cdap-standalone/target', 'ggn-archive/cdap-build' )
    }}}

	stage("RPM PUSH"){
	  steps{
	    script{
	    sh ''
	  rpm_push( env.buildType, '${WORKSPACE}/cdap/**/target', 'ggn-dev-rpms/cdap-build' )
	  rpm_push( env.buildType, '${WORKSPACE}/cdap-ambari-service/target', 'ggn-dev-rpms/cdap-build' )
	  rpm_push( env.buildType, '${WORKSPACE}', 'ggn-dev-rpms/cdap-build' )
	  deb_push(env.buildType, env.ARTIFACT_SRC1, env.ARTIFACT_DEST1 )
          deb_push(env.buildType, env.ARTIFACT_SRC2, env.ARTIFACT_DEST1 ) 
    }}}
  }
	
post {
       always {
          reports_alerts('target/checkstyle-result.xml', 'target/surefire-reports/*.xml', '**/target/site/cobertura/coverage.xml', 'allure-report/', 'index.html')
     	  slackalert('jenkins-cdap-alerts')
       }
    }

}
