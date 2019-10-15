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
def openmpfBranch = env.openmpf_branch
def openmpfComponentsBranch = env.openmpf_components_branch
def openmpfContribComponentsBranch = env.openmpf_contrib_components_branch
def openmpfCppComponentSdkBranch = env.openmpf_cpp_component_sdk_branch
def openmpfJavaComponentSdkBranch = env.openmpf_java_component_sdk_branch
def openmpfPythonComponentSdkBranch = env.openmpf_python_component_sdk_branch
def openmpfBuildToolsBranch = env.openmpf_build_tools_branch

def openmpfDockerBranch = env.openmpf_docker_branch ?: 'develop'


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

// These properties are for applying custom configurations to images
def applyCustomConfig = env.apply_custom_config?.toBoolean() ?: false
def openmpfConfigDockerRepo = env.openmpf_config_docker_repo
def openmpfConfigDockerSlug = env.openmpf_config_docker_slug
def openmpfConfigDockerBranch = env.openmpf_config_docker_branch



def buildPackageJson = env.build_package_json

def imageTag = env.image_tag
def buildNoCache = env.build_no_cache?.toBoolean() ?: false

def preserveContainersOnFailure = env.preserve_containers_on_failure?.toBoolean() ?: false

def dockerRegistryHost = env.docker_registry_host
def dockerRegistryPort = env.docker_registry_port
def dockerRegistryPath = env.docker_registry_path ?: "/openmpf"
def dockerRegistryCredId = env.docker_registry_cred_id;
def pushRuntimeImages = env.push_runtime_images?.toBoolean() ?: false

def postOpenmpfDockerBuildStatus = env.post_openmpf_docker_build_status?.toBoolean() ?: false
def githubAuthToken = env.github_auth_token
def emailRecipients = env.email_recipients



class Repo {
    String name
    String url
    String path
    String branch
    String sha

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

def openmpfRepo = new Repo('openmpf', 'https://github.com/openmpf/openmpf.git',
        'openmpf-projects/openmpf', openmpfBranch)

def openmpfComponentsRepo = new Repo('openmpf-components', 'https://github.com/openmpf/openmpf-components.git',
        'openmpf-projects/openmpf-components', openmpfComponentsBranch)

def openmpfContribComponentsRepo = new Repo('openmpf-contrib-components',
        'https://github.com/openmpf/openmpf-contrib-components.git',
        'openmpf-projects/openmpf-contrib-components', openmpfContribComponentsBranch)

def openmpfCppSdkRepo = new Repo('openmpf-cpp-component-sdk',
        'https://github.com/openmpf/openmpf-cpp-component-sdk.git',
        'openmpf-projects/openmpf-cpp-component-sdk', openmpfCppComponentSdkBranch),

def opnmpfJavaSdkRepo = new Repo('openmpf-java-component-sdk',
        'https://github.com/openmpf/openmpf-java-component-sdk.git',
        'openmpf-projects/openmpf-java-component-sdk', openmpfJavaComponentSdkBranch),

def openmpfPythonSdkRepo = new Repo('openmpf-python-component-sdk', 'https://github.com/openmpf/openmpf-python-component-sdk.git',
        'openmpf-projects/openmpf-python-component-sdk', openmpfPythonComponentSdkBranch),

def openmpfBuildToolsRepo = new Repo('openmpf-build-tools',
        'https://github.com/openmpf/openmpf-build-tools.git',
        'openmpf-projects/openmpf-build-tools', openmpfBuildToolsBranch),

def projectsSubRepos = [ openmpfRepo, openmpfComponentsRepo, openmpfContribComponentsRepo, openmpfCppSdkRepo,
                         opnmpfJavaSdkRepo, openmpfPythonSdkRepo, openmpfBuildToolsRepo ]

def customConfigRepo = new Repo(openmpfConfigDockerSlug, openmpfConfigDockerRepo, openmpfConfigDockerSlug,
        openmpfConfigDockerBranch)

def customRepos = []
if (buildCustomComponents) {
    customRepos.add(new Repo(openmpfCustomDockerSlug, openmpfCustomDockerRepo, openmpfCustomDockerSlug,
            openmpfCustomDockerBranch))

    customRepos.add(new Repo(openmpfCustomComponentsSlug, openmpfCustomComponentsRepo, openmpfCustomComponentsSlug,
            openmpfCustomComponentsBranch))

    customRepos.add(new Repo(openmpfCustomSystemTestsSlug, openmpfCustomSystemTestsRepo, openmpfCustomSystemTestsSlug,
            openmpfCustomSystemTestsBranch))
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

    def workflowManagerImageName = "${remoteImagePrefix}openmpf_workflow_manager:$imageTag"
    def activeMqImageName = "${remoteImagePrefix}openmpf_activemq:$imageTag"
    def cppBuildImageName = "${remoteImagePrefix}openmpf_cpp_component_build:$imageTag"
    def cppExecutorImageName = "${remoteImagePrefix}openmpf_cpp_executor:$imageTag"
    def pythonExecutorImageName = "${remoteImagePrefix}openmpf_python_executor:$imageTag"

    stage('Clone repos') {

        if (!fileExists(openmpfProjectsRepo.path)) {
            sh "git clone --recurse-submodules $openmpfProjectsRepo.url"
        }
        dir(openmpfProjectsRepo.path) {
            sh 'git clean -ffd'
            sh 'git submodule foreach git clean -ffd'
            sh 'git fetch'
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

    def componentComposeFiles
    def runtimeComposeFiles

    stage('Build images') {
        sh 'docker pull centos:7' // Make sure we are using the most recent centos:7 release

        if (buildPackageJson.contains('/')) {
            sh "cp $buildPackageJson openmpf-projects/openmpf/trunk/jenkins/scripts/config_files"
            buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
        }

        withEnv(['DOCKER_BUILDKIT=1', 'RUN_TESTS=true']) {
            def noCacheArg = buildNoCache ? '--no-cache' : ''
            def commonBuildArgs = " --build-arg BUILD_REGISTRY='$remoteImagePrefix' " +
                    "--build-arg BUILD_TAG='$imageTag' $noCacheArg "

            dir ('openmpf-docker') {
                def shasArg = getShasBuildArg([openmpfDockerRepo, openmpfProjectsRepo] + projectsSubRepos);
                sh 'docker build -f openmpf_build/Dockerfile ../openmpf-projects --build-arg RUN_TESTS ' +
                        "--build-arg BUILD_PACKAGE_JSON=$buildPackageJson $commonBuildArgs $shasArg " +
                        " -t ${remoteImagePrefix}openmpf_build:$imageTag"

                sh "docker build integration_tests $commonBuildArgs $shasArg " +
                        " -t ${remoteImagePrefix}openmpf_integration_tests:$imageTag"
            }

            if (buildCustomComponents) {
                sh "docker build $openmpfCustomSystemTestsSlug $commonBuildArgs ${getShasBuildArg(allRepos)} " +
                        " -t ${remoteImagePrefix}openmpf_integration_tests:$imageTag "
            }


            dir('openmpf-docker/components') {
                def cppShas = getShasBuildArg([openmpfCppSdkRepo, openmpfDockerRepo])
                sh "docker build . -f cpp_component_build/Dockerfile $commonBuildArgs $cppShas " +
                        " -t $cppBuildImageName"

                sh "docker build . -f cpp_executor/Dockerfile $commonBuildArgs $cppShas " +
                        " -t $cppExecutorImageName"

                def pythonShas = getShasBuildArg([openmpfPythonSdkRepo, openmpfDockerRepo])
                sh "docker build . -f python_executor/Dockerfile $commonBuildArgs $pythonShas " +
                        " -t $pythonExecutorImageName"
            }

            dir ('openmpf-docker') {
                sh 'cp .env.tpl .env'

                def shasArg = getShasBuildArg(allRepos)

                componentComposeFiles = 'docker-compose.components.yml'
                if (buildCustomComponents) {
                    def customComponentsYml = "../$openmpfCustomDockerSlug/docker-compose.custom-components.yml"
                    if (fileExists(customComponentsYml)) {
                        componentComposeFiles += ":$customComponentsYml"
                    }
                }
                runtimeComposeFiles = "docker-compose.core.yml:$componentComposeFiles"

                withEnv(["TAG=$imageTag", "REGISTRY=$remoteImagePrefix", "COMPOSE_FILE=$runtimeComposeFiles"]) {
                    def shasArg = getShasBuildArg(allRepos)
                    sh "docker-compose build $commonBuildArgs $shasArg --build-arg RUN_TESTS"
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
        buildStatus = "aborted"
    }
    else if (buildException != null) {
        echo 'DETECTED BUILD FAILURE'
        echo 'Exception type: ' + buildException.getClass()
        echo 'Exception message: ' + buildException.getMessage()
        buildStatus = "failure"
    }
    else {
        echo 'DETECTED BUILD COMPLETED'
        echo "CURRENT BUILD RESULT: ${currentBuild.currentResult}"
        buildStatus = currentBuild.currentResult.equals("SUCCESS") ? "success" : "failure"
    }

    if (postOpenmpfDockerBuildStatus) {
        postBuildStatus(openmpfDockerRepo, buildStatus, githubAuthToken)
        for (repo in projectsSubRepos) {
            postBuildStatus(repo, buildStatus, githubAuthToken)
        }
    }
    email(buildStatus, emailRecipients)
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
