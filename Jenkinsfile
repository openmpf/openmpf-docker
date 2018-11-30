/******************************************************************************
 * NOTICE                                                                     *
 *                                                                            *
 * This software (or technical data) was produced for the U.S. Government     *
 * under contract, and is subject to the Rights in Data-General Clause        *
 * 52.227-14, Alt. IV (DEC 2007).                                             *
 *                                                                            *
 * Copyright 2018 The MITRE Corporation. All Rights Reserved.                 *
 ******************************************************************************/

/******************************************************************************
 * Copyright 2018 The MITRE Corporation                                       *
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
def runIntegrationTests = env.getProperty("run_integration_tests").toBoolean()
def buildProductionImages = env.getProperty("build_production_images").toBoolean()
def dockerRegistryHost = env.getProperty("docker_registry_host")
def dockerRegistryPort = env.getProperty("docker_registry_port")
def dockerRegistryCredId = env.getProperty("docker_registry_cred_id")
def jenkinsNodes = env.getProperty("jenkins_nodes")
// def buildNum = env.getProperty("BUILD_NUMBER")
// def workspacePath = env.getProperty("WORKSPACE")

def buildCustomComponents = env.getProperty("build_custom_components").toBoolean()
def openmpfCustomRepoCredId = env.getProperty('openmpf_custom_repo_cred_id')
def openmpfCustomDockerRepo = env.getProperty("openmpf_custom_docker_repo")
def openmpfCustomDockerSlug = env.getProperty("openmpf_custom_docker_slug")
def openmpfCustomDockerBranch = env.getProperty("openmpf_custom_docker_branch")
def openmpfCustomComponentsRepo = env.getProperty("openmpf_custom_components_repo")
def openmpfCustomComponentsRepoCredId = env.getProperty('openmpf_custom_components_repo_cred_id')
def openmpfCustomComponentsSlug = env.getProperty("openmpf_custom_components_slug")
def openmpfCustomComponentsBranch = env.getProperty("openmpf_custom_components_branch")
def openmpfCustomSystemTestsRepo = env.getProperty("openmpf_custom_system_tests_repo")
def openmpfCustomSystemTestsRepoCredId = env.getProperty('openmpf_custom_system_tests_repo_cred_id')
def openmpfCustomSystemTestsSlug = env.getProperty("openmpf_custom_system_tests_slug")
def openmpfCustomSystemTestsBranch = env.getProperty("openmpf_custom_system_tests_branch")

node(jenkinsNodes) {
    try {
        def dockerRegistryHostAndPort = dockerRegistryHost + ':' + dockerRegistryPort
        def remoteImageTagPrefix = dockerRegistryHostAndPort + '/openmpf/'
        def remoteImageTagPrefixEscaped = dockerRegistryHostAndPort + '\\/openmpf\\/'
        def buildImageName = remoteImageTagPrefix + 'openmpf_build:' + imageTag
        def customBuildImageName = remoteImageTagPrefix + 'openmpf_custom_build:' + imageTag
        def postBuildImageName = 'openmpf_post_build:' + imageTag
        def buildContainerId
        def postBuildImageId

        /*
        stage('TEST') {
            sh "echo 'CURRENT BUILD RESULT:_${currentBuild.currentResult}_'"
            sh 'exit 1' // DEBUG
        }
        */

        stage('Clone repos') {

            gitCheckoutAndPull("https://github.com/openmpf/openmpf-docker.git",
                    '.', openmpfDockerBranch)

            // Revert changes made to files by a previous Jenkins build.
            sh 'git reset --hard HEAD '

            def openmpfProjectsPath = 'openmpf_build/openmpf-projects'
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-projects.git",
                    openmpfProjectsPath, openmpfProjectsBranch)
            sh 'cd ' + openmpfProjectsPath + '; git submodule update --init'

            gitCheckoutAndPull("https://github.com/openmpf/openmpf.git",
                    openmpfProjectsPath + '/openmpf', openmpfBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-components.git",
                    openmpfProjectsPath + '/openmpf-components', openmpfComponentsBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-contrib-components.git",
                    openmpfProjectsPath + '/openmpf-contrib-components', openmpfContribComponentsBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-cpp-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-cpp-component-sdk', openmpfCppComponentSdkBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-java-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-java-component-sdk', openmpfJavaComponentSdkBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-python-component-sdk.git",
                    openmpfProjectsPath + '/openmpf-python-component-sdk', openmpfPythonComponentSdkBranch)
            gitCheckoutAndPull("https://github.com/openmpf/openmpf-build-tools.git",
                    openmpfProjectsPath + '/openmpf-build-tools', openmpfBuildToolsBranch)

            if (buildCustomComponents) {
                def openmpfCustomDockerPath = 'openmpf_custom_build'
                gitCheckoutAndPullWithCredId(openmpfCustomDockerRepo, openmpfCustomRepoCredId,
                        openmpfCustomDockerPath, openmpfCustomDockerBranch)

                // Copy custom component build files into place (SDKs, etc.)
                sh 'cp -u /data/openmpf/custom-build-files/* ' + openmpfCustomDockerPath

                def openmpfCustomComponentsPath = openmpfProjectsPath + '/' + openmpfCustomComponentsSlug
                gitCheckoutAndPullWithCredId(openmpfCustomComponentsRepo, openmpfCustomRepoCredId,
                        openmpfCustomComponentsPath, openmpfCustomComponentsBranch)

                def openmpfCustomSystemTestsPath = openmpfProjectsPath + '/' + openmpfCustomSystemTestsSlug
                gitCheckoutAndPullWithCredId(openmpfCustomSystemTestsRepo, openmpfCustomRepoCredId,
                        openmpfCustomSystemTestsPath, openmpfCustomSystemTestsBranch)
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

            // sh 'exit -1' // DEBUG
        }

        docker.withRegistry('http://' + dockerRegistryHostAndPort, dockerRegistryCredId) {

            stage('Build base image') {
                sh 'docker build openmpf_build/ -t ' + buildImageName

                if (buildCustomComponents) {
                    sh 'docker build openmpf_custom_build/ --build-arg BUILD_IMAGE_NAME=' + buildImageName +
                            ' -t ' + customBuildImageName

                    // Use the custom build from now on.
                    buildImageName = customBuildImageName
                }

                // sh 'exit -1' // DEBUG
            }

            stage('Build OpenMPF') {
                if (!buildOpenmpf) {
                    sh 'echo "SKIPPING OPENMPF BUILD"'
                }
                when (buildOpenmpf) { // if false, don't show this step in the Stage View UI
                    try {
                        if (!runUnitTests) {
                            sh 'echo "SKIPPING UNIT TESTS"'
                        }

                        // Run container as daemon in background to capture container id
                        buildContainerId = sh(script: 'docker run -d ' +
                                '--mount type=bind,source=/home/jenkins/.m2,target=/root/.m2 ' +
                                '--mount type=bind,source="$(pwd)"/openmpf_runtime/build_artifacts,target=/mnt/build_artifacts ' +
                                '--mount type=bind,source="$(pwd)"/openmpf_build/openmpf-projects,target=/mnt/openmpf-projects ' +
                                '-e BUILD_PACKAGE_JSON=' + buildPackageJson + ' ' +
                                '-e RUN_TESTS=' + (runUnitTests ? 1 : 0) + ' ' +
                                buildImageName, returnStdout: true)

                        // Remove trailing newline.
                        buildContainerId = buildContainerId.trim()

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
                    } catch (Exception e) {
                        if (buildContainerId != null) {
                            sh(script: 'docker container rm -f ' + buildContainerId, returnStatus:true)
                        }
                        throw e; // rethrow so Jenkins knows of failure
                    } finally {
                        if (!runIntegrationTests && buildContainerId != null) {
                            sh(script: 'docker container rm -f ' + buildContainerId, returnStatus:true)
                        }
                    }
                }
            }

            stage('Commit post-build image') {
                // Save the post-build image to run system tests.
                if (!buildOpenmpf || !runIntegrationTests) {
                    sh 'echo "SKIPPING COMMIT OF POST-BUILD IMAGE"'
                }
                when (buildOpenmpf && runIntegrationTests) { // if false, don't show this step in the Stage View UI
                    try {
                        postBuildImageId = sh(script: 'docker commit ' + buildContainerId +
                                ' ' + postBuildImageName, returnStdout: true)
                    } finally {
                        sh(script: 'docker container rm -f ' + buildContainerId, returnStatus:true)
                    }
                }
            }

            stage('Run system tests') {
                if (!runIntegrationTests) {
                    sh 'echo "SKIPPING INTEGRATION TESTS"'
                }
                when (runIntegrationTests) { // if false, don't show this step in the Stage View UI
                    try {
                        sh 'sed "s/~\\/\\.m2/\\/home\\/jenkins\\/\\.m2/g"' +
                                ' docker-compose-test.yml > docker-compose.yml'

                        sh(script:'docker-compose rm -svf', returnStatus:true)
                        sh(script:'docker volume rm -f openmpf-docker_mpf_data', returnStatus:true)
                        sh(script:'docker volume rm -f openmpf-docker_mysql_data', returnStatus:true)

                        sh 'docker-compose build --build-arg BUILD_IMAGE_NAME=' + buildImageName +
                                ' --build-arg POST_BUILD_IMAGE_NAME=' + postBuildImageName

                        sh 'docker-compose up --force-recreate' +
                                ' --abort-on-container-exit --exit-code-from workflow_manager_test'

                        // Touch files to avoid the following error if the test reports are more than 3 seconds old:
                        // "Test reports were found but none of them are new"

                        sh 'sudo touch openmpf_runtime/build_artifacts/surefire-reports/*.xml'
                        junit 'openmpf_runtime/build_artifacts/surefire-reports/*.xml'

                        sh 'sudo touch openmpf_runtime/build_artifacts/failsafe-reports/*.xml'
                        junit 'openmpf_runtime/build_artifacts/failsafe-reports/*.xml'
                    } finally {
                        // Stop and remove containers, networks, and volumes
                        sh(script: 'docker-compose down --volumes', returnStatus:true)
                        if (postBuildImageId != null) {
                            // Discard the post build image
                            // sh(script: 'docker image rm -f ' + postBuildImageId, returnStatus:true) // DEBUG
                        }
                    }
                }
            }

            stage('Build production images') {
                if (!buildProductionImages) {
                    sh 'echo "SKIPPING BUILD OF PRODUCTION IMAGES"'
                }
                when (buildProductionImages) { // if false, don't show this step in the Stage View UI
                    sh 'cp docker-compose.yml.bak docker-compose.yml'
                    sh 'docker-compose build --build-arg BUILD_IMAGE_NAME=' + buildImageName
                }
            }

            stage('Push production images') {
                if (!buildProductionImages) {
                    sh 'echo "SKIPPING PUSH OF PRODUCTION IMAGES"'
                }
                when (buildProductionImages) { // if false, don't show this step in the Stage View UI
                    // Pushing multiple tags is cheap, as all the layers are reused.
                    sh 'docker push ' + buildImageName
                    sh 'docker-compose push'
                }
            }

        } // end docker.withRegistry(
    } catch(Exception e) {
        if (isAborted()) {
            sh 'echo "DETECTED BUILD ABORTED"'
            email("ABORTED")
        } else {
            sh 'echo "DETECTED BUILD FAILURE"'
            email("FAILURE")
        }
        throw e; // rethrow so Jenkins knows of failure
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
}

def gitCheckoutAndPullWithCredId(String repo, String credId, String dir, String branch) {
    checkout([$class: 'GitSCM',
              branches: [[name: '*/' + branch]],
              extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: dir]],
              userRemoteConfigs: [[credentialsId: credId, url: repo]]])

    // TODO: Make sure we're not in a detached state.
    // sh 'cd ' + dir + '; git checkout ' + branch
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