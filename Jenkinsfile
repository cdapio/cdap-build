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
	SONAR_PATH = './cdap'
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
		    
	}}}
	  
stage('SonarQube analysis') {
steps {
script {
sonarqube(env.SONAR_PATH)
timeout(time: 1, unit: 'HOURS') {
def qg = waitForQualityGate()
if (qg.status != 'OK') {
error "Pipeline aborted due to quality gate failure: ${qg.status}"
}
}
}
}
}

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
