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

def imageTag = env.image_tag ?: 'deleteme'
def buildNoCache = env.build_no_cache?.toBoolean() ?: false
def preserveContainersOnFailure = env.preserve_containers_on_failure?.toBoolean() ?: false
def buildPackageJson = env.build_package_json ?: 'openmpf-non-docker-components-package.json'

def buildCustomComponents = env.build_custom_components?.toBoolean() ?: false
def openmpfCustomRepoCredId = env.openmpf_custom_repo_cred_id
def applyCustomConfig = env.apply_custom_config?.toBoolean() ?: false

def dockerRegistryHost = env.docker_registry_host
def dockerRegistryPort = env.docker_registry_port
def dockerRegistryPath = env.docker_registry_path ?: "/openmpf"
def dockerRegistryCredId = env.docker_registry_cred_id;
def pushRuntimeImages = env.push_runtime_images?.toBoolean() ?: false

def pollReposAndEndBuild = env.poll_repos_and_end_build?.toBoolean() ?: false

def postOpenmpfDockerBuildStatus = env.post_openmpf_docker_build_status?.toBoolean() ?: false
def githubAuthToken = env.github_auth_token
def emailRecipients = env.email_recipients



class Repo {
    String name
    String url
    String path
    String branch
    String sha
    String prevSha

    private Repo(path, url, branch, name) {
        this.path = path
        this.url = url;
        this.branch = branch
        this.name = name;
    }

    Repo(path, url, branch) {
        this(path, url, branch, path)
    }

    static Repo projectsSubRepo(name, branch) {
        return new Repo("openmpf-projects/$name", null, branch, name)
    }
}


def openmpfProjectsRepo = new Repo('openmpf-projects', 'https://github.com/openmpf/openmpf-projects.git',
        env.openmpf_projects_branch ?: 'develop')


def openmpfDockerRepo = new Repo('openmpf-docker', 'https://github.com/openmpf/openmpf-docker.git',
        env.openmpf_docker_branch ?: 'develop')


def openmpfRepo = Repo.projectsSubRepo('openmpf', env.openmpf_branch)


def openmpfComponentsRepo = Repo.projectsSubRepo('openmpf-components', env.openmpf_components_branch)

def openmpfContribComponentsRepo = Repo.projectsSubRepo('openmpf-contrib-components',
        env.openmpf_contrib_components_branch)

def openmpfCppSdkRepo = Repo.projectsSubRepo('openmpf-cpp-component-sdk', env.openmpf_cpp_component_sdk_branch)

def opnmpfJavaSdkRepo = Repo.projectsSubRepo('openmpf-java-component-sdk', env.openmpf_java_component_sdk_branch)

def openmpfPythonSdkRepo = Repo.projectsSubRepo('openmpf-python-component-sdk',
        env.openmpf_python_component_sdk_branch)

def openmpfBuildToolsRepo = Repo.projectsSubRepo('openmpf-build-tools', env.openmpf_build_tools_branch)


def projectsSubRepos = [ openmpfRepo, openmpfComponentsRepo, openmpfContribComponentsRepo, openmpfCppSdkRepo,
                         opnmpfJavaSdkRepo, openmpfPythonSdkRepo, openmpfBuildToolsRepo ]


def customComponentsRepo = new Repo(env.openmpf_custom_components_slug, env.openmpf_custom_components_repo,
        env.openmpf_custom_components_branch ?: 'develop')

def customSystemTestsRepo = new Repo(env.openmpf_custom_system_tests_slug, env.openmpf_custom_system_tests_repo,
        env.openmpf_custom_system_tests_branch ?: 'develop')

def customConfigRepo = new Repo(env.openmpf_config_docker_slug, env.openmpf_config_docker_repo,
        env.openmpf_config_docker_branch ?: 'develop')

def customRepos = []
if (buildCustomComponents) {
    customRepos.add(customComponentsRepo)
    customRepos.add(customSystemTestsRepo)
    if (applyCustomConfig) {
        customRepos.add(customConfigRepo)
    }
}

def allRepos = [openmpfDockerRepo, openmpfProjectsRepo] + projectsSubRepos + customRepos


node(env.jenkins_nodes) {
wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console
def buildException

try {
    def buildId = "${currentBuild.projectName}_${currentBuild.number}"


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

    def workflowManagerImageName = "${remoteImagePrefix}openmpf_workflow_manager:$imageTag"
    def activeMqImageName = "${remoteImagePrefix}openmpf_activemq:$imageTag"
    def cppBuildImageName = "${remoteImagePrefix}openmpf_cpp_component_build:$imageTag"
    def cppExecutorImageName = "${remoteImagePrefix}openmpf_cpp_executor:$imageTag"
    def pythonExecutorImageName = "${remoteImagePrefix}openmpf_python_executor:$imageTag"

    stage('Clone repos') {
        for (repo in allRepos) {
            if (fileExists(repo.path)) {
                repo.prevSha = sh(script: "cd $repo.path && git rev-parse HEAD", returnStdout: true).trim()
            }
            else {
                repo.prevSha = 'NONE'
            }
        }

        if (!fileExists(openmpfProjectsRepo.path)) {
            sh "git clone --recurse-submodules $openmpfProjectsRepo.url"
        }
        dir(openmpfProjectsRepo.path) {
            sh 'git clean -ffd'
            sh 'git submodule foreach git clean -ffd'
            sh 'git fetch --recurse-submodules'
            sh "git checkout 'origin/$openmpfProjectsRepo.branch'"
            sh 'git submodule update'
        }
        for (repo in projectsSubRepos) {
            if (repo.branch && !repo.branch.isAllWhitespace()) {
                sh "cd '$repo.path' && git checkout 'origin/$repo.branch'"
            }
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

    stage('Check repos for updates') {
        if (!pollReposAndEndBuild) {
            echo 'SKIPPING REPO UPDATE CHECK'
        }

        when (pollReposAndEndBuild) {
            echo 'CHANGES:'

            def requiresBuild = false

            for (repo in allRepos) {
                requiresBuild |= (repo.prevSha != repo.sha)
                echo "$repo.name: $repo.prevSha --> $repo.sha"
            }
            echo "REQUIRES BUILD: $requiresBuild"
            currentBuild.result = requiresBuild ? 'SUCCESS' : 'ABORTED';
        }

    } // stage('Check repos for updates')
    if (pollReposAndEndBuild) {
        return // end build early; do this outside of a stage
    }

    def componentComposeFiles
    def runtimeComposeFiles

    stage('Build images') {
        // Make sure we are using most recent version of external images
        for (externalImage in ['centos:7', 'webcenter/activemq', 'mariadb:latest', 'redis:latest']) {
            sh "docker pull '$externalImage'"
        }

        if (buildPackageJson.contains('/')) {
            sh "cp $buildPackageJson openmpf-projects/openmpf/trunk/jenkins/scripts/config_files"
            buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
        }

        withEnv(['DOCKER_BUILDKIT=1', 'RUN_TESTS=true']) {
            def noCacheArg = buildNoCache ? '--no-cache' : ''
            def commonBuildArgs = " --build-arg BUILD_REGISTRY='$remoteImagePrefix' " +
                    "--build-arg BUILD_TAG='$imageTag' $noCacheArg "

            dir ('openmpf-docker') {
                sh 'docker build -f openmpf_build/Dockerfile ../openmpf-projects --build-arg RUN_TESTS ' +
                        "--build-arg BUILD_PACKAGE_JSON=$buildPackageJson $commonBuildArgs " +
                        " -t ${remoteImagePrefix}openmpf_build:$imageTag"

                sh "docker build integration_tests $commonBuildArgs " +
                        " -t ${remoteImagePrefix}openmpf_integration_tests:$imageTag"
            }

            if (buildCustomComponents) {
                sh "docker build $customSystemTestsRepo.path $commonBuildArgs ${getShasBuildArg(allRepos)} " +
                        " -t ${remoteImagePrefix}openmpf_integration_tests:$imageTag "
            }


            dir('openmpf-docker/components') {
                def cppShas = getShasBuildArg([openmpfCppSdkRepo])
                sh "docker build . -f cpp_component_build/Dockerfile $commonBuildArgs $cppShas " +
                        " -t $cppBuildImageName"

                sh "docker build . -f cpp_executor/Dockerfile $commonBuildArgs $cppShas " +
                        " -t $cppExecutorImageName"

                def pythonShas = getShasBuildArg([openmpfPythonSdkRepo])
                sh "docker build . -f python_executor/Dockerfile $commonBuildArgs $pythonShas " +
                        " -t $pythonExecutorImageName"
            }

            dir ('openmpf-docker') {
                sh 'cp .env.tpl .env'

                componentComposeFiles = 'docker-compose.components.yml'
                if (buildCustomComponents) {
                    def customComponentsYml = "../$customComponentsRepo.path/docker-compose.custom-components.yml"
                    if (fileExists(customComponentsYml)) {
                        componentComposeFiles += ":$customComponentsYml"
                    }
                }
                runtimeComposeFiles = "docker-compose.core.yml:$componentComposeFiles"

                withEnv(["TAG=$imageTag", "REGISTRY=$remoteImagePrefix", "COMPOSE_FILE=$runtimeComposeFiles"]) {
                    def shasArg = getShasBuildArg(allRepos)
                    sh "docker-compose build $commonBuildArgs $shasArg --build-arg RUN_TESTS --parallel"
                }
            }

            if (applyCustomConfig) {
                echo 'APPLYING CUSTOM CONFIGURATION'
                dir(customConfigRepo.path) {
                    def wfmShasArg = getShasBuildArg([openmpfDockerRepo, customConfigRepo, openmpfRepo])
                    sh "docker build workflow_manager $commonBuildArgs $wfmShasArg " +
                            " -t $workflowManagerImageName"

                    def amqShasArg = getShasBuildArg([openmpfDockerRepo, customConfigRepo])
                    sh "docker build activemq $commonBuildArgs $amqShasArg " +
                            " -t $activeMqImageName"
                }
            }
            else  {
                echo 'SKIPPING CUSTOM CONFIGURATION'
            }
        } // withEnv
    } // stage('Build images')

    stage('Run Integration Tests') {
        dir('openmpf-docker') {
            def composeFiles = "docker-compose.integration.test.yml:$componentComposeFiles"

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
    stage('Push runtime images') {
        if (!pushRuntimeImages) {
            echo 'SKIPPING PUSH OF RUNTIME IMAGES'
        }
        when (pushRuntimeImages) {
            withEnv(["TAG=$imageTag", "REGISTRY=$remoteImagePrefix", "COMPOSE_FILE=$runtimeComposeFiles"]) {
                docker.withRegistry("http://$dockerRegistryHostAndPort", dockerRegistryCredId) {
                    sh 'cd openmpf-docker && docker-compose push'
                    sh "docker push '${cppBuildImageName}'"
                    sh "docker push '${cppExecutorImageName}'"
                    sh "docker push '${pythonExecutorImageName}'"
                } // docker.withRegistry ...
            } // withEnv...
        } // when (pushRuntimeImages)
    } // stage('Push runtime images')
}
catch (e) { // Global exception handler
    buildException = e
    throw e
}
finally {
    def buildStatus
    if (isAborted()) {
        echo 'DETECTED BUILD ABORTED'
        buildStatus = 'failure'
    }
    else if (buildException != null) {
        echo 'DETECTED BUILD FAILURE'
        echo 'Exception type: ' + buildException.getClass()
        echo 'Exception message: ' + buildException.getMessage()
        buildStatus = 'failure'
    }
    else {
        echo 'DETECTED BUILD COMPLETED'
        echo "CURRENT BUILD RESULT: ${currentBuild.currentResult}"
        buildStatus = currentBuild.currentResult == 'SUCCESS' ? 'success' : 'failure'
    }

    if (postOpenmpfDockerBuildStatus) {
        postBuildStatus(openmpfDockerRepo, buildStatus, githubAuthToken)
        for (repo in projectsSubRepos) {
            postBuildStatus(repo, buildStatus, githubAuthToken)
        }
    }
    email(buildStatus, emailRecipients)

    // Remove dangling <none> images that are more than 2 weeks old.
    sh 'docker image prune --force --filter "until=336h"'
    sh 'docker builder prune --force --keep-storage=80GB'
}
} // wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm'])
} // node(env.jenkins_nodes)




def getShasBuildArg(repos) {
    def shas = repos.collect { "$it.name: $it.sha" }.join(', ')
    return " --build-arg BUILD_SHAS='$shas' "
}


def isAborted() {
    return currentBuild.result == 'ABORTED' ||
            !currentBuild.getRawBuild().getActions(jenkins.model.InterruptedBuildAction).isEmpty()
}

def postBuildStatus(repo, status, githubAuthToken) {
    if (!repo.branch || repo.branch.isAllWhitespace()) {
        return
    }

    def description = "$currentBuild.projectName $currentBuild.displayName"
    def statusJson = /{ "state": "$status", "description": "$description", "context": "jenkins" }/
    def url = "https://api.github.com/repos/openmpf/$repo.name/statuses/$repo.sha"
    def response = sh(script:
            "curl -s -X POST -H 'Authorization: token $githubAuthToken' -d '$statusJson' $url",
            returnStdout: true)

    def resultJson = readJSON(text: response)

    def success = (resultJson.state == status && resultJson.description == description
                    && resultJson.context == "jenkins")
    if (!success) {
        echo 'Failed to post build status:'
        echo response
    }
}

def email(status, recipients) {
    emailext(
        subject: "$status: $env.JOB_NAME [$env.BUILD_NUMBER]",
        body: '${JELLY_SCRIPT,template="text"}',
        recipientProviders: [[$class: 'RequesterRecipientProvider']],
        to: recipients);
}
