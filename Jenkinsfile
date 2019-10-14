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

def dockerRegistryHost = env.docker_registry_host
def dockerRegistryPort = env.docker_registry_port
def dockerRegistryPath = env.docker_registry_path ?: "/openmpf"


// These properties are for building with custom components
def buildCustomComponents = env.build_custom_components?.toBoolean() ?: false
def openmpfCustomRepoCredId = env.openmpf_custom_repo_cred_id


def openmpfCustomDockerRepo = env.openmpf_custom_docker_repo
def openmpfCustomDockerSlug = env.openmpf_custom_docker_slug
def openmpfCustomDockerBranch = env.openmpf_custom_docker_branch ?: 'develop'


def openmpfCustomComponentsRepo = env.openmpf_custom_components_repo
def openmpfCustomComponentsSlug = env.openmpf_custom_components_slug
def openmpfCustomComponentsBranch = env.openmpf_custom_components_branch ?: 'develop'

def openmpfCustomSystemTestsRepo = env.openmpf_custom_system_tests_repo
def openmpfCustomSystemTestsSlug = env.openmpf_custom_system_tests_slug
def openmpfCustomSystemTestsBranch = env.openmpf_custom_system_tests_branch ?: 'develop'


class Repo {
    def name
    def url
    def path
    def branch
    def sha

    Repo(name, url, path, branch) {
        this.name = name;
        this.url = url;
        this.path = path
        this.branch = branch
    }
}

def openmpfProjectsRepo = new Repo('openmpf-projects', 'https://github.com/openmpf/openmpf-projects.git',
        'openmpf-projects', openmpfProjectsBranch)

def openmpfDockerRepo = new Repo('openmpf-docker', 'https://github.com/openmpf/openmpf-docker.git',
        'openmpf-docker', openmpfDockerBranch)

def coreRepos = [
        new Repo('openmpf', 'https://github.com/openmpf/openmpf.git',
                'openmpf-projects/openmpf', openmpfBranch),

        new Repo('openmpf-components', 'https://github.com/openmpf/openmpf-components.git',
                'openmpf-projects/openmpf-components', openmpfComponentsBranch),

        new Repo('openmpf-contrib-components', 'https://github.com/openmpf/openmpf-contrib-components.git',
                'openmpf-projects/openmpf-contrib-components', openmpfContribComponentsBranch),

        new Repo('openmpf-cpp-component-sdk', 'https://github.com/openmpf/openmpf-cpp-component-sdk.git',
                'openmpf-projects/openmpf-cpp-component-sdk', openmpfCppComponentSdkBranch),

        new Repo('openmpf-java-component-sdk', 'https://github.com/openmpf/openmpf-java-component-sdk.git',
                'openmpf-projects/openmpf-java-component-sdk', openmpfJavaComponentSdkBranch),

        new Repo('openmpf-python-component-sdk', 'https://github.com/openmpf/openmpf-python-component-sdk.git',
                'openmpf-projects/openmpf-python-component-sdk', openmpfPythonComponentSdkBranch),

        new Repo('openmpf-build-tools', 'https://github.com/openmpf/openmpf-build-tools.git',
                'openmpf-projects/openmpf-build-tools', openmpfBuildToolsBranch),
]

def customRepos = []
if (buildCustomComponents) {
    customRepos.add(new Repo(openmpfCustomDockerSlug, openmpfCustomDockerRepo, openmpfCustomDockerSlug,
            openmpfCustomDockerBranch))

    customRepos.add(new Repo(openmpfCustomComponentsSlug, openmpfCustomComponentsRepo, openmpfCustomComponentsSlug,
            openmpfCustomComponentsBranch))

    customRepos.add(new Repo(openmpfCustomSystemTestsSlug, openmpfCustomSystemTestsRepo, openmpfCustomSystemTestsSlug,
            openmpfCustomSystemTestsBranch))
}

def allRepos = [openmpfDockerRepo, openmpfProjectsRepo] + coreRepos + customRepos


node(env.jenkins_nodes) {
wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console

    def buildId = "${currentBuild.projectName}_${currentBuild.number}"
    def buildDate = sh(script: 'date --iso-8601=seconds', returnStdout: true).trim()


    def dockerRegistryHostAndPort = dockerRegistryHost
    if (dockerRegistryPort) {
        dockerRegistryHostAndPort += ':' + dockerRegistryPort
    }

    def remoteImagePrefix = dockerRegistryHostAndPort
    if (dockerRegistryPath) {
        if (!dockerRegistryPath.startsWith("/")) {
            remoteImagePrefix += "/"
        }
        remoteImagePrefix += dockerRegistryPath
        if (!dockerRegistryPath.endsWith("/")) {
            remoteImagePrefix += "/"
        }
    }


    stage('Clone repos') {

        if (!fileExists(openmpfProjectsRepo.path)) {
            sh "git clone --recurse-submodules $openmpfProjectsRepo.url"
        }
        dir(openmpfProjectsRepo.path) {
            sh 'git clean -ffd'
            sh 'git submodule foreach git clean -ffd'
            sh 'git fetch'
            sh "git checkout 'origin/$openmpfProjectsRepo.branch'"
        }
        for (repo in coreRepos) {
            sh "cd '$repo.path' && git checkout 'origin/$repo.branch'"
        }


        if (!fileExists(openmpfDockerRepo.path)) {
            sh "git clone $openmpfDockerRepo.url"
        }
        dir(openmpfDockerRepo.path) {
            sh 'git clean -ffd'
            sh 'git fetch'
            sh "git checkout 'origin/$openmpfDockerRepo.branch'"
        }

        for (repo in customRepos) {
            checkout(
                    $class: 'GitSCM',
                    userRemoteConfigs: [[url: repo.url, credentialsId: openmpfCustomRepoCredId]],
                    branches: [[name: repo.branch]],
                    extensions: [
                            [$class: 'CleanBeforeCheckout'],
                            [$class: 'RelativeTargetDirectory', relativeTargetDir: repo.path]])
        }

        for (repo in allRepos) {
            repo.sha = sh(script: "cd $repo.path && git rev-parse HEAD", returnStdout: true).trim()
        }
    } // stage('Clone repos')

    stage('Build images') {
        sh 'docker pull centos:7' // Make sure we are using the most recent centos:7 release

        if (buildPackageJson.contains('/')) {
            sh "cp $buildPackageJson openmpf-projects/openmpf/trunk/jenkins/scripts/config_files"
            buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
        }

        withEnv(['DOCKER_BUILDKIT=1', 'RUN_TESTS=true']) {
            buildShas = getBuildShasStr(allRepos)
//            def commonBuildArgs = " --build-arg BUILD_REGISTRY='$remoteImagePrefix' " +
//                    "--build-arg BUILD_TAG='$imageTag' --build-arg BUILD_DATE='$buildDate' " +
//                    "--build-arg BUILD_SHAS='$buildShas' ";
            def commonBuildArgs = " --build-arg BUILD_REGISTRY='$remoteImagePrefix' " +
                    "--build-arg BUILD_TAG='$imageTag' --build-arg BUILD_SHAS='$buildShas' ";


            dir ('openmpf-docker') {
                sh 'docker build -f openmpf_build/Dockerfile ../openmpf-projects --build-arg RUN_TESTS ' +
                        "--build-arg BUILD_PACKAGE_JSON=$buildPackageJson $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_build:$imageTag"

                sh "docker build integration_tests $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_integration_tests:$imageTag"
            }

            if (buildCustomComponents) {
                sh "docker build $openmpfCustomSystemTestsSlug $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_integration_tests:$imageTag "
            }


            dir('openmpf-docker/components') {
                sh "docker build . -f cpp_component_build/Dockerfile $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_cpp_component_build:$imageTag"

                sh "docker build . -f cpp_executor/Dockerfile $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_cpp_executor:$imageTag"

                sh "docker build . -f python_executor/Dockerfile $commonBuildArgs " +
                        "-t ${remoteImagePrefix}openmpf_python_executor:$imageTag"
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
                withEnv(["TAG=$imageTag", "REGISTRY=$remoteImagePrefix", "COMPOSE_FILE=$composeFiles"]) {
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
                     "REGISTRY=$remoteImagePrefix",
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
                finally {
                    junit 'test-reports/*-reports/*.xml'
                }
            } // withEnv
        } // dir('openmpf-docker')
    } // stage('Run Integration Tests')
} // wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm'])
} // node(env.jenkins_nodes)

def getBuildShasStr(repos) {
    repos.collect { "$it.name: $it.sha" }.join(', ')
}
