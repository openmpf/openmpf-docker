/******************************************************************************
 * NOTICE                                                                     *
 *                                                                            *
 * This software (or technical data) was produced for the U.S. Government     *
 * under contract, and is subject to the Rights in Data-General Clause        *
 * 52.227-14, Alt. IV (DEC 2007).                                             *
 *                                                                            *
 * Copyright 2019 The MITRE Corporation. All Rights Reserved.                 *
 ******************************************************************************/

/******************************************************************************
 * Copyright 2019 The MITRE Corporation                                       *
 *                                                                            *
 * Licensed under the Apache License, Version 2.0 (the "License");            *
 * you may not use this file except in compliance with the License.           *
 * You may obtain a copy of the License at                                    *
 *                                                                            *
 *    http://www.apache.org/licenses/LICENSE-2.0                              *
 *                                                                            *
 * Unless required by applicable law or agreed to in writing, software        *
 * distributed under the License is distributed on an "AS IS" BASIS,          *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *
 * See the License for the specific language governing permissions and        *
 * limitations under the License.                                             *
 ******************************************************************************/

// Get build parameters.
def imageTag = env.getProperty("image_tag")
def openmpfDockerBranch = env.getProperty("openmpf_docker_branch")
def openmpfProjectsBranch = env.getProperty("openmpf_projects_branch")
def openmpfBranch = env.getProperty("openmpf_branch")
def openmpfComponentsBranch = env.getProperty("openmpf_components_branch")
def openmpfContribComponentsBranch = env.getProperty("openmpf_contrib_components_branch")
def openmpfCppComponentSdkBranch = env.getProperty("openmpf_cpp_component_sdk_branch")
def openmpfJavaComponentSdkBranch = env.getProperty("openmpf_java_component_sdk_branch")
def openmpfPythonComponentSdkBranch = env.getProperty("openmpf_python_component_sdk_branch")
def openmpfBuildToolsBranch = env.getProperty("openmpf_build_tools_branch")

def buildPackageJson = env.getProperty("build_package_json")
def buildOpenmpf = env.getProperty("build_openmpf").toBoolean()
def runUnitTests = env.getProperty("run_unit_tests").toBoolean()
def mvnUnitTestOptions = env.getProperty("mvn_unit_test_options")
def runIntegrationTests = env.getProperty("run_integration_tests").toBoolean()
def mvnIntegrationTestOptions = env.getProperty("mvn_integration_test_options")
def buildRuntimeImages = env.getProperty("build_runtime_images").toBoolean()
def pushRuntimeImages = env.getProperty("push_runtime_images").toBoolean()

def dockerRegistryHost = env.getProperty("docker_registry_host")
def dockerRegistryPort = env.getProperty("docker_registry_port")
def dockerRegistryCredId = env.getProperty("docker_registry_cred_id")
def jenkinsNodes = env.getProperty("jenkins_nodes")
// def buildNum = env.getProperty("BUILD_NUMBER")
// def workspacePath = env.getProperty("WORKSPACE")

// These properties are for building with custom components
def buildCustomComponents = env.getProperty("build_custom_components").toBoolean()
def openmpfCustomRepoCredId = env.getProperty('openmpf_custom_repo_cred_id')
def openmpfCustomDockerRepo = env.getProperty("openmpf_custom_docker_repo")
def openmpfCustomDockerBranch = env.getProperty("openmpf_custom_docker_branch")
def openmpfCustomComponentsRepo = env.getProperty("openmpf_custom_components_repo")
def openmpfCustomComponentsSlug = env.getProperty("openmpf_custom_components_slug")
def openmpfCustomComponentsBranch = env.getProperty("openmpf_custom_components_branch")
def openmpfCustomSystemTestsRepo = env.getProperty("openmpf_custom_system_tests_repo")
def openmpfCustomSystemTestsSlug = env.getProperty("openmpf_custom_system_tests_slug")
def openmpfCustomSystemTestsBranch = env.getProperty("openmpf_custom_system_tests_branch")

// These properties are for applying custom configurations to images
def applyCustomConfig = env.getProperty("apply_custom_config").toBoolean()
def openmpfConfigRepoCredId = env.getProperty('openmpf_config_repo_cred_id')
def openmpfConfigDockerRepo = env.getProperty("openmpf_config_docker_repo")
def openmpfConfigDockerBranch = env.getProperty("openmpf_config_docker_branch")

// Labels
def buildDate
def buildShas
def openmpfCustomDockerSha
def openmpfCustomComponentsSha
def openmpfCustomSystemTestsSha
def openmpfConfigDockerSha

node(jenkinsNodes) {
    try {
        buildDate = getTimestamp()

        def dockerRegistryHostAndPort = dockerRegistryHost + ':' + dockerRegistryPort
        def remoteImageTagPrefix = dockerRegistryHostAndPort + '/openmpf/'

        def buildImageName = remoteImageTagPrefix + 'openmpf_build:' + imageTag
        def buildContainerId

        def workflowManagerImageName = remoteImageTagPrefix + 'openmpf_workflow_manager:' + imageTag

        /*
        stage('TEST') {
            sh "echo 'CURRENT BUILD RESULT:_${currentBuild.currentResult}_'"
            sh 'exit 1' // DEBUG
        }
        */

        stage('Clone repos') {

            def openmpfDockerSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-docker.git",
                    '.', openmpfDockerBranch)

            // Revert changes made to files by a previous Jenkins build.
            sh 'git reset --hard HEAD '

            def openmpfProjectsPath = 'openmpf_build/openmpf-projects'
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-projects.git",
                    openmpfProjectsPath, openmpfProjectsBranch)
            sh 'cd ' + openmpfProjectsPath + '; git submodule update --init'

            def openmpfSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf.git",
                    openmpfProjectsPath + '/openmpf', openmpfBranch)
            def openmpfComponentsSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-components.git",
                    openmpfProjectsPath + '/openmpf-components', openmpfComponentsBranch)
            def openmpfContribComponentsSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-contrib-components.git",
                    openmpfProjectsPath + '/openmpf-contrib-components', openmpfContribComponentsBranch)
            def openmpfCppComponentSdkSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-cpp-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-cpp-component-sdk', openmpfCppComponentSdkBranch)
            def openmpfJavaComponentSdkSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-java-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-java-component-sdk', openmpfJavaComponentSdkBranch)
            def openmpfPythonComponentSdkSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-python-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-python-component-sdk', openmpfPythonComponentSdkBranch)
            def openmpfBuildToolsSha = gitCheckoutAndPull("https://github.com/openmpf/openmpf-build-tools.git",
                    openmpfProjectsPath + '/openmpf-build-tools', openmpfBuildToolsBranch)

            buildShas = 'openmpf-docker: ' + openmpfDockerSha +
                    ', openmpf: ' + openmpfSha +
                    ', openmpf-components: ' + openmpfComponentsSha +
                    ', openmpf-contrib-components: ' + openmpfContribComponentsSha +
                    ', openmpf-cpp-component-sdk: ' + openmpfCppComponentSdkSha +
                    ', openmpf-java-component-sdk: ' + openmpfJavaComponentSdkSha +
                    ', openmpf-python-component-sdk: ' + openmpfPythonComponentSdkSha +
                    ', openmpf-build-tools: ' + openmpfBuildToolsSha

            if (buildCustomComponents) {
                def openmpfCustomDockerPath = 'openmpf_custom_build'
                openmpfCustomDockerSha = gitCheckoutAndPullWithCredId(openmpfCustomDockerRepo, openmpfCustomRepoCredId,
                        openmpfCustomDockerPath, openmpfCustomDockerBranch)

                // Copy custom component build files into place (SDKs, etc.)
                sh 'cp -u /data/openmpf/custom-build-files/* ' + openmpfCustomDockerPath

                def openmpfCustomComponentsPath = openmpfProjectsPath + '/' + openmpfCustomComponentsSlug
                openmpfCustomComponentsSha = gitCheckoutAndPullWithCredId(openmpfCustomComponentsRepo, openmpfCustomRepoCredId,
                        openmpfCustomComponentsPath, openmpfCustomComponentsBranch)

                def openmpfCustomSystemTestsPath = openmpfProjectsPath + '/' + openmpfCustomSystemTestsSlug
                openmpfCustomSystemTestsSha = gitCheckoutAndPullWithCredId(openmpfCustomSystemTestsRepo, openmpfCustomRepoCredId,
                        openmpfCustomSystemTestsPath, openmpfCustomSystemTestsBranch)
            }

            if (applyCustomConfig) {
                def openmpfConfigDockerPath = 'openmpf_custom_config'
                openmpfConfigDockerSha = gitCheckoutAndPullWithCredId(openmpfConfigDockerRepo, openmpfConfigRepoCredId,
                        openmpfConfigDockerPath, openmpfConfigDockerBranch)
            }

            // Copy JDK into place
            sh 'cp -u /data/openmpf/jdk-*-linux-x64.rpm openmpf_build'

            // Copy *package.json into place
            if (buildPackageJson.contains("/")) {
                sh 'cp ' + buildPackageJson + ' ' + openmpfProjectsPath +
                        '/openmpf/trunk/jenkins/scripts/config_files'
                buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
            }

            // Generate compose files
            sh './scripts/docker-generate-compose-files.sh ' + dockerRegistryHost + ':' +
                    dockerRegistryPort + ' openmpf ' + imageTag
            sh 'cp docker-compose.yml docker-compose.yml.bak'

            // TODO: Attempt to pull images in separate stage so that they are not
            // built from scratch on a clean Jenkins node.
        }

        docker.withRegistry('http://' + dockerRegistryHostAndPort, dockerRegistryCredId) {

            stage('Build base image') {
                sh 'docker build openmpf_build/' +
                        ' --build-arg BUILD_DATE=' + buildDate +
                        ' --build-arg BUILD_VERSION=' + imageTag +
                        ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                        ' -t ' + buildImageName

                if (buildCustomComponents) {
                    buildShas += ', openmpf-custom-docker: ' + openmpfCustomDockerSha +
                            ', openmpf-custom-components: ' + openmpfCustomComponentsSha +
                            ', openmpf-custom-system-tests: ' + openmpfCustomSystemTestsSha

                    // Build the new build image for custom components using the original build image for open source
                    // components. This overwrites the original build image tag.
                    sh 'docker build openmpf_custom_build/' +
                            ' --build-arg BUILD_IMAGE_NAME=' + buildImageName +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_VERSION=' + imageTag +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                            ' -t ' + buildImageName
                }
            }

            if (!buildOpenmpf) {
                sh 'echo "SKIPPING OPENMPF BUILD"'
            }
            when (buildOpenmpf) { // if false, don't show this step in the Stage View UI
                try {
                    // Show color in Jenkins console.
                    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {

                        stage('Build OpenMPF') {
                            // Run container as daemon in background to capture container id.
                            buildContainerId = sh(script: 'docker run -t -d ' +
                                    '--mount type=bind,source=/home/jenkins/.m2,target=/root/.m2 ' +
                                    '--mount type=bind,source="$(pwd)"/openmpf_runtime/build_artifacts,target=/mnt/build_artifacts ' +
                                    '--mount type=bind,source="$(pwd)"/openmpf_build/openmpf-projects,target=/mnt/openmpf-projects ' +
                                    '--mount type=volume,source=openmpf_shared_data,target=/home/mpf/openmpf-projects/openmpf/trunk/install/share ' +
                                    buildImageName, returnStdout: true).trim()

                            sh(script: 'docker exec ' + buildContainerId + ' touch first-run.txt', returnStatus: true)
                            // sh(script: 'docker exec ' + buildContainerId + ' /home/mpf/docker-entrypoint.sh', returnStatus:true)
                        }

                        if (!runIntegrationTestsTests) {
                            sh 'echo "SKIPPING INTEGRATION TESTS"'
                        }
                        when(runIntegrationTestsTests) { // if false, don't show this step in the Stage View UI
                            stage('Run system tests') {
                                sh(script: 'docker exec ' + buildContainerId + ' ls', returnStatus: true)
                                // sh(script: 'docker exec ' + buildContainerId + ' /home/mpf/run-tests.sh', returnStatus:true)
                            }
                        }
                    }
                } catch (Exception e) {
                    throw e // rethrow so Jenkins knows of failure
                } finally {
                    if (buildContainerId != null) {
                        sh(script: 'docker container rm -f ' + buildContainerId, returnStatus: true)
                    }
                }



                                /*
                                docker.image(buildImageName).inside {

                                    stage('First Run') {
                                        sh 'touch first-run.txt'
                                    }

                                    stage('Second Run') {
                                        sh 'ls'
                                    }
                                    */

                                    /*

                                    buildContainerId = sh(script: 'docker run -d ' +
                                            '--mount type=bind,source=/home/jenkins/.m2,target=/root/.m2 ' +
                                            '--mount type=bind,source="$(pwd)"/openmpf_runtime/build_artifacts,target=/mnt/build_artifacts ' +
                                            '--mount type=bind,source="$(pwd)"/openmpf_build/openmpf-projects,target=/mnt/openmpf-projects ' +
                                            '--mount type=volume,source=openmpf_shared_data,target=/home/mpf/openmpf-projects/openmpf/trunk/install/share ' +
                                            '-e BUILD_PACKAGE_JSON=' + buildPackageJson + ' ' +
                                            '-e RUN_TESTS=' + (runUnitTests ? 1 : 0) + ' ' +
                                            '-e MVN_OPTIONS=\"' + mvnUnitTestOptions + '\" ' +
                                            buildImageName, returnStdout: true).trim()
                                    */
                                }
                        //}

                        /*
                        // Attach to container to show log output and wait until entrypoint completes
                        def dockerRunRetVal = sh(script:'docker attach ' + buildContainerId, returnStatus:true)

                        if (runUnitTests) {
                            // Touch files to avoid the following error if the test reports are more than 3 seconds old:
                            // "Test reports were found but none of them are new"

                            sh 'sudo touch openmpf_runtime/build_artifacts/surefire-reports/*.xml'
                            junit 'openmpf_runtime/build_artifacts/surefire-reports/*.xml'

                            sh 'sudo touch openmpf_runtime/build_artifacts/gtest-reports/*.xml'
                            junit 'openmpf_runtime/build_artifacts/gtest-reports/*.xml'

                            // // junit 'openmpf_runtime/build_artifacts/failsafe-reports/*.xml'
                        }

                        if (dockerRunRetVal != 0) {
                            sh 'exit ' + dockerRunRetVal
                        }
                        */

            /*
            stage('Run system tests') {
                if (!runIntegrationTests) {
                    sh 'echo "SKIPPING INTEGRATION TESTS"'
                }
                when (runIntegrationTests) { // if false, don't show this step in the Stage View UI
                    try {
                        sh(script:'docker-compose rm -svf', returnStatus:true)
                        sh(script:'docker volume rm -f openmpf_shared_data', returnStatus:true)
                        sh(script:'docker volume rm -f openmpf_mysql_data', returnStatus:true)

                        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                            sh 'docker-compose build' +
                                    ' --build-arg BUILD_IMAGE_NAME=' + buildImageName +
                                    ' --build-arg POST_BUILD_IMAGE_NAME=' + postBuildImageName +
                                    ' --build-arg BUILD_DATE=' + buildDate +
                                    ' --build-arg BUILD_VERSION=' + imageTag +
                                    ' --build-arg BUILD_SHAS=\"' + buildShas + '\"'

                            sh 'docker exec --entrypoint /opt/mpf/run-tests.sh'
                        }

                        // Touch files to avoid the following error if the test reports are more than 3 seconds old:
                        // "Test reports were found but none of them are new"

                        sh 'sudo touch openmpf_runtime/build_artifacts/surefire-reports/*.xml'
                        junit 'openmpf_runtime/build_artifacts/surefire-reports/*.xml'

                        sh 'sudo touch openmpf_runtime/build_artifacts/failsafe-reports/*.xml'
                        junit 'openmpf_runtime/build_artifacts/failsafe-reports/*.xml'
                    } finally {
                        // Stop and remove containers, networks, and volumes
                        // TODO: Make "--volumes" flag configurable.
                        // TODO: Prefix shared volume with Jenkins build name to prevent simultaneous build conflicts.
                        sh(script: 'docker-compose down ', returnStatus:true)
                        sh(script: 'docker container rm -f ' + buildContainerId, returnStatus:true)
                    }
                }
            }

            stage('Build runtime images') {
                if (!buildRuntimeImages) {
                    sh 'echo "SKIPPING BUILD OF RUNTIME IMAGES"'
                }
                when (buildRuntimeImages) { // if false, don't show this step in the Stage View UI
                    sh 'cp docker-compose.yml.bak docker-compose.yml'
                    sh 'docker-compose build' +
                            ' --build-arg BUILD_IMAGE_NAME=' + buildImageName +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_VERSION=' + imageTag +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"'
                }

                if (applyCustomConfig) {
                    buildShas += ', openmpf-config-docker: ' + openmpfConfigDockerSha

                    // Build and tag the new Workflow Manager image with the image tag used in the compose files.
                    // That way, we do not have to modify the compose files. This overwrites the tag that referred to
                    // the original Workflow Manager image without the custom config.
                    sh 'docker build openmpf_custom_config/workflow_manager' +
                            ' --build-arg BUILD_IMAGE_NAME=' + workflowManagerImageName +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_VERSION=' + imageTag +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                            ' -t ' + workflowManagerImageName
                }
            }

            stage('Push runtime images') {
                if (!pushRuntimeImages) {
                    sh 'echo "SKIPPING PUSH OF RUNTIME IMAGES"'
                }
                when (pushRuntimeImages) { // if false, don't show this step in the Stage View UI
                    // Pushing multiple tags is cheap, as all the layers are reused.
                    sh 'docker push ' + buildImageName
                    sh 'docker-compose push'
                }
            }
            */

        } // end docker.withRegistry(
    } catch(Exception e) {
        if (isAborted()) {
            sh 'echo "DETECTED BUILD ABORTED"'
            email("ABORTED")
        } else {
            sh 'echo "DETECTED BUILD FAILURE"'
            sh 'echo "Exception type: "' + e.getClass()
            sh 'echo "Exception message: "' + e.getMessage()
            email("FAILURE")
        }
        throw e // rethrow so Jenkins knows of failure
    }

    if (isAborted()) {
        sh 'echo "DETECTED BUILD ABORTED"'
        email("ABORTED")
    } else {
        // if we get here then the build completed
        sh 'echo "DETECTED BUILD COMPLETED"'
        sh "echo 'CURRENT BUILD RESULT: ${currentBuild.currentResult}'"
        email(currentBuild.currentResult)
    }
}

def gitCheckoutAndPull(String repo, String dir, String branch) {
    // This is the official procedure, but we don't want all of the "Git Build Data"
    // entries clogging up the sidebar in the build UI:
    // checkout([$class: 'GitSCM',
    //    branches: [[name: '*/' + branch]],
    //    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: dir]],
    //    userRemoteConfigs: [[url: repo]]])

    if (!fileExists(dir + '/.git')) {
        sh 'git clone ' + repo + ' ' + dir
    }

    sh 'cd ' + dir + '; git fetch'
    sh 'cd ' + dir + '; git checkout ' + branch
    sh 'cd ' + dir + '; git pull origin ' + branch

    return sh(script: 'cd ' + dir + '; git rev-parse HEAD', returnStdout: true).trim()
}

def gitCheckoutAndPullWithCredId(String repo, String credId, String dir, String branch) {
    def scmVars = checkout([$class: 'GitSCM',
              branches: [[name: '*/' + branch]],
              extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: dir]],
              userRemoteConfigs: [[credentialsId: credId, url: repo]]])

    // TODO: Make sure we're not in a detached state.
    // sh 'cd ' + dir + '; git checkout ' + branch

    return scmVars.GIT_COMMIT
}

def isAborted() {
    def actions = currentBuild.getRawBuild().getActions(jenkins.model.InterruptedBuildAction)
    return !actions.isEmpty()
}

def email(String status) {
    emailext (
            subject: status + ": ${env.JOB_NAME} [${env.BUILD_NUMBER}]",
            // mimeType: 'text/html',
            // body: "<p>Check console output at <a href=\"${env.BUILD_URL}\">${env.BUILD_URL}</a></p>",
            body: '${JELLY_SCRIPT,template="text"}',
            recipientProviders: [[$class: 'RequesterRecipientProvider']]
    )
}

def getTimestamp() {
    return sh(script: 'date --iso-8601=seconds', returnStdout: true).trim()
}
