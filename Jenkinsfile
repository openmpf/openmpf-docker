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

def openmpfProjectsBranch = env.openmpf_projects_branch ?: 'develop'
def openmpfBranch = env.openmpf_branch ?: 'develop'
def openmpfComponentsBranch = env.openmpf_components_branch ?: 'develop'
def openmpfContribComponentsBranch = env.openmpf_contrib_components_branch ?: 'develop'
def openmpfCppComponentSdkBranch = env.openmpf_cpp_component_sdk_branch ?: 'develop'
def openmpfJavaComponentSdkBranch = env.openmpf_java_component_sdk_branch ?: 'develop'
def openmpfPythonComponentSdkBranch = env.openmpf_python_component_sdk_branch ?: 'develop'
def openmpfBuildToolsBranch = env.openmpf_build_tools_branch ?: 'develop'

def openmpfDockerBranch = env.openmpf_docker_branch ?: 'develop'

def buildPackageJson = env.build_package_json

def imageTag = env.image_tag

def preserveContainersOnFailure = env.preserve_containers_on_failure?.toBoolean() ?: false


// These properties are for building with custom components
def buildCustomComponents = env.build_custom_components?.toBoolean() ?: false

def openmpfCustomDockerRepo = env.openmpf_custom_docker_repo
def openmpfCustomDockerSlug = env.openmpf_custom_docker_slug
def openmpfCustomDockerBranch = env.openmpf_custom_docker_branch ?: 'develop'


def openmpfCustomComponentsRepo = env.openmpf_custom_components_repo
def openmpfCustomComponentsSlug = env.openmpf_custom_components_slug
def openmpfCustomComponentsBranch = env.openmpf_custom_components_branch ?: 'develop'

def openmpfCustomSystemTestsRepo = env.openmpf_custom_system_tests_repo
def openmpfCustomSystemTestsSlug = env.openmpf_custom_system_tests_slug
def openmpfCustomSystemTestsBranch = env.openmpf_custom_system_tests_branch ?: 'develop'





node(env.jenkins_nodes) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console

    def buildId = "${currentBuild.projectName}_${currentBuild.number}"

    stage('Clone repos') {
        if (!fileExists('openmpf-projects')) {
            sh 'git clone --recurse-submodules https://github.com/openmpf/openmpf-projects.git'
        }
        dir('openmpf-projects') {
            sh 'git clean -ffd'
            sh 'git submodule foreach git clean -ffd'
            sh 'git fetch'
            sh "git checkout 'origin/$openmpfProjectsBranch'"

            sh "cd openmpf && git checkout 'origin/$openmpfBranch'"

            sh "cd openmpf-components && git checkout 'origin/$openmpfComponentsBranch'"

            sh "cd openmpf-contrib-components && git checkout 'origin/$openmpfContribComponentsBranch'"

            sh "cd openmpf-cpp-component-sdk && git checkout 'origin/$openmpfCppComponentSdkBranch'"

            sh "cd openmpf-java-component-sdk && git checkout 'origin/$openmpfJavaComponentSdkBranch'"

            sh "cd openmpf-python-component-sdk && git checkout 'origin/$openmpfPythonComponentSdkBranch'"

            sh "cd openmpf-build-tools && git checkout 'origin/$openmpfBuildToolsBranch'"
        }

        if (!fileExists('openmpf-docker')) {
            sh 'git clone https://github.com/openmpf/openmpf-docker.git'
        }
        dir('openmpf-docker') {
            sh 'git clean -ffd'
            sh 'git fetch'
            sh "git checkout 'origin/$openmpfDockerBranch'"
        }

        if (buildCustomComponents) {
            custom_repos = [
                [url: openmpfCustomDockerRepo, branch: openmpfCustomDockerBranch,
                     dir: openmpfCustomDockerSlug],
                [url: openmpfCustomComponentsRepo, branch: openmpfCustomComponentsBranch,
                    dir: openmpfCustomComponentsSlug],
                [url: openmpfCustomSystemTestsRepo, branch: openmpfCustomSystemTestsBranch,
                    dir: openmpfCustomSystemTestsSlug]
            ]
            for (repo in custom_repos) {
                checkout(
                        $class: 'GitSCM',
                        userRemoteConfigs: [[url: repo.url, credentialsId: openmpfCustomRepoCredId]],
                        branches: [[name: repo.branch]],
                        extensions: [
                                [$class: CleanBeforeCheckout],
                                [$class: 'RelativeTargetDirectory', relativeTargetDir: repo.dir]])
            }
        }

    } // stage('Clone repos')

    stage('Build images') {
        sh 'docker pull centos:7' // Make sure we are using the most recent centos:7 release

        if (buildPackageJson.contains('/')) {
            sh "cp $buildPackageJson openmpf-projects/openmpf/trunk/jenkins/scripts/config_files"
            buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
        }
        withEnv(['DOCKER_BUILDKIT=1', 'RUN_TESTS=true', "BUILD_TAG=$imageTag"]) {
            def commonBuildArgs = '--build-arg BUILD_TAG'

            dir ('openmpf-docker') {
                sh 'docker build -f openmpf_build/Dockerfile ../openmpf-projects --build-arg RUN_TESTS ' +
                        "--build-arg BUILD_PACKAGE_JSON=$buildPackageJson  -t openmpf_build:$imageTag"

                sh "docker build integration_tests -t openmpf_integration_tests:$imageTag $commonBuildArgs"
            }

            if (buildCustomComponents) {
                sh "docker build $openmpfCustomSystemTestsSlug -t openmpf_integration_tests:$imageTag $commonBuildArgs"
            }


            dir('openmpf-docker/components') {
                sh "docker build . -f cpp_component_build/Dockerfile -t openmpf_cpp_component_build:$imageTag " +
                        "$commonBuildArgs"

                sh "docker build . -f cpp_executor/Dockerfile -t openmpf_cpp_executor:$imageTag $commonBuildArgs"

                sh "docker build . -f python_executor/Dockerfile -t openmpf_python_executor:$imageTag $commonBuildArgs"
            }

            dir ('openmpf-docker') {
                sh 'cp .env.tpl .env'
                def composeFiles = 'docker-compose.core.yml:docker-compose.components.yml'
                if (buildCustomComponents) {
                    def customComponentsYml = "../$openmpfCustomDockerSlug/docker-compose.custom-components.yml"
                    if (fileExists(customComponentsYml)) {
                        composeFiles += ":$customComponentsYml"
                    }
                }
                withEnv(["TAG=$imageTag", "COMPOSE_FILE=$composeFiles"]) {
                    sh "docker-compose build $commonBuildArgs --build-arg RUN_TESTS"
                }
            }
        }
    } // stage('Build images')
    stage('Run Integration Tests') {
        dir('openmpf-docker') {
            def composeFiles = 'docker-compose.integration.test.yml:docker-compose.components.yml'
            if (buildCustomComponents) {
                def customComponentsYml = "../$openmpfCustomDockerSlug/docker-compose.custom-components.yml"
                if (fileExists(customComponentsYml)) {
                    composeFiles += ":$customComponentsYml"
                }
            }

            withEnv(["TAG=$imageTag",
                     // Use custom project name to allow multiple builds on same machine
                     "COMPOSE_PROJECT_NAME=openmpf_$buildId",
                     "COMPOSE_FILE=$composeFiles"]) {
                try {
                    sh 'docker-compose up --exit-code-from workflow-manager'
                    sh 'docker-compose down --volumes'
                }
                catch (e) {
                    if (preserveContainersOnFailure) {
                        sh 'docker-compose stop'
                    }
                    else {
                        sh 'docker-compose down --volumes'
                    }
                    throw e;
                }
            } // withEnv
        } // dir('openmpf-docker')
    } // stage('Run Integration Tests')
} // wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm'])
} // node(env.jenkins_nodes)
