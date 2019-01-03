@Library('jenkins_lib')_
pipeline {
  agent {label 'slave'}
	
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
		def REL_BUILD_NO = currentBuild.getNumber()
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
		mvn install -DskipTests -Dcheckstyle.skip=true -B -am -pl cdap/cdap-api -P templates && \
		mvn install -DskipTests -Dcheckstyle.skip=true -B -am -f cdap/cdap-app-templates -P templates && \
		rm -rf ${env.WORKSPACE}/cdap/*/target/*.rpm  && \
		rm -rf ${env.WORKSPACE}/ansible_rpm/*.rpm  && \
		mvn package -P examples,templates,dist,release,rpm-prepare,rpm,deb-prepare,deb \
		-DskipTests \
		-Dcheckstyle.skip=true \
		-Dadditional.artifacts.dir=${env.WORKSPACE}/app-artifacts \
		-Dsecurity.extensions.dir=${env.WORKSPACE}/security-extensions -DbuildNumber=${REL_BUILD_NO}   \
		"""
	}}}
	  
	//stage('SonarQube analysis') {
	  //steps {
	    //script {
	      //def scannerHome = tool 'sonar';
		//withSonarQubeEnv('sonar') {
		//echo "sonar"
		//sh 'cd ${WORKSPACE}/source && mvn sonar:sonar'
            //}}}}
	  
	stage("RPM PUSH"){
	  steps{
	    script{
	    sh ''
//	    rpm_push( env.buildType, '.', 'ggn-dev-rpms/cdap-build' )
	  rpm_push( env.buildType, '${env.WORKSPACE}/cdap/**/target', 'ggn-dev-rpms/cdap-build' )
    }}}
  }
	
post {
       always {
          reports_alerts('source/target/checkstyle-result.xml', 'source/target/surefire-reports/*.xml', 'source/**/target/site/cobertura/coverage.xml', 'allure-report/', 'index.html')
     	  slackalert('jenkins-cdap-alerts')
       }
    }

}
