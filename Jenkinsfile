/******************************************************************************
 * NOTICE                                                                     *
 *                                                                            *
 * This software (or technical data) was produced for the U.S. Government     *
 * under contract, and is subject to the Rights in Data-General Clause        *
 * 52.227-14, Alt. IV (DEC 2007).                                             *
 *                                                                            *
 * Copyright 2023 The MITRE Corporation. All Rights Reserved.                 *
 ******************************************************************************/

/******************************************************************************
 * Copyright 2023 The MITRE Corporation                                       *
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

// Ensure that the hosts running this build have the login credentials for the
// <docker_registry_host>:<docker_registry_port> cached in ~/.docker/config.json.
// Also, consider caching the credentials for Docker Hub (index.docker.io) and
// NVIDIA (nvcr.io) to avoid rate limiting.

def imageTag = env.image_tag ?: 'deleteme'
def buildNoCache = env.build_no_cache?.toBoolean() ?: false
def preserveContainersOnFailure = env.preserve_containers_on_failure?.toBoolean() ?: false

def buildCustomComponents = env.build_custom_components?.toBoolean() ?: false
def openmpfCustomRepoCredId = env.openmpf_custom_repo_cred_id
def applyCustomConfig = env.apply_custom_config?.toBoolean() ?: false
def mvnTestOptions = env.mvn_test_options ?: ''

def dockerRegistryHost = env.docker_registry_host
def dockerRegistryPort = env.docker_registry_port
def dockerRegistryPath = env.docker_registry_path ?: "/openmpf"
def pushRuntimeImages = env.push_runtime_images?.toBoolean() ?: false

def pollReposAndEndBuild = env.poll_repos_and_end_build?.toBoolean() ?: false

def postBuildStatusEnabled = env.post_build_status?.toBoolean()  ?: false
def githubAuthToken = env.github_auth_token
def emailRecipients = env.email_recipients

// These properties add optional user-defined labels to the Docker images
def imageUrl = env.getProperty("image_url")
def imageVersion = env.getProperty("image_version") ?: ""
def customLabelKey = env.getProperty("custom_label_key") ?: "custom"

def preDockerBuildScriptPath = env.pre_docker_build_script_path

def runTrivyScans = env.run_trivy_scans?.toBoolean() ?: false
def skipIntegrationTests = env.skip_integration_tests?.toBoolean() ?: false
def pruneDocker = env.prune_docker?.toBoolean() ?: false
def buildTimeout = env.build_timeout ?: 6 // hours

env.DOCKER_BUILDKIT=1
env.COMPOSE_DOCKER_CLI_BUILD=1

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


def openmpfDockerRepo = Repo.projectsSubRepo('openmpf-docker', env.openmpf_docker_branch)

def openmpfRepo = Repo.projectsSubRepo('openmpf', env.openmpf_branch)


def openmpfComponentsRepo = Repo.projectsSubRepo('openmpf-components', env.openmpf_components_branch)

def openmpfContribComponentsRepo = Repo.projectsSubRepo('openmpf-contrib-components',
        env.openmpf_contrib_components_branch)

def openmpfCppSdkRepo = Repo.projectsSubRepo('openmpf-cpp-component-sdk', env.openmpf_cpp_component_sdk_branch)

def openmpfJavaSdkRepo = Repo.projectsSubRepo('openmpf-java-component-sdk', env.openmpf_java_component_sdk_branch)

def openmpfPythonSdkRepo = Repo.projectsSubRepo('openmpf-python-component-sdk',
        env.openmpf_python_component_sdk_branch)

def openmpfBuildToolsRepo = Repo.projectsSubRepo('openmpf-build-tools', env.openmpf_build_tools_branch)


def projectsSubRepos = [ openmpfRepo, openmpfDockerRepo, openmpfComponentsRepo, openmpfContribComponentsRepo,
                         openmpfCppSdkRepo, openmpfJavaSdkRepo, openmpfPythonSdkRepo, openmpfBuildToolsRepo ]


def customComponentsRepo = new Repo(env.openmpf_custom_components_slug, env.openmpf_custom_components_repo,
        env.openmpf_custom_components_branch ?: 'develop')

def customSystemTestsRepo = new Repo(env.openmpf_custom_system_tests_slug, env.openmpf_custom_system_tests_repo,
        env.openmpf_custom_system_tests_branch ?: 'develop')

def customConfigRepo = new Repo(env.openmpf_config_docker_slug, env.openmpf_config_docker_repo,
        env.openmpf_config_docker_branch ?: 'develop')

def customRepos = []
if (buildCustomComponents) {
    customRepos << customComponentsRepo << customSystemTestsRepo
    if (applyCustomConfig) {
        customRepos << customConfigRepo
    }
}

def allRepos = [openmpfProjectsRepo] + projectsSubRepos + customRepos


node(env.jenkins_nodes) {
wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console

def buildException
def inProgressTag

try {
    def buildId = "${currentBuild.projectName}_${currentBuild.number}"
    // Use inProgressTag to ensure concurrent builds don't use the same image tag.
    inProgressTag = buildId


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
        for (repo in allRepos) {
            if (fileExists(repo.path)) {
                repo.prevSha = shOutput "cd $repo.path && git rev-parse HEAD"
            }
            else {
                repo.prevSha = 'NONE'
            }
        }

        // Directory may not exist. In that case the command doesn't do anything.
        sh "rm -rf $openmpfDockerRepo.path/test-reports/*"

        if (!fileExists(openmpfProjectsRepo.path)) {
            sh "git clone --recurse-submodules $openmpfProjectsRepo.url"
        }
        dir(openmpfProjectsRepo.path) {
            sh 'git clean -ffd'
            sh 'git submodule foreach git clean -ffd'
            sh 'git fetch --recurse-submodules'
            sh "git checkout 'origin/$openmpfProjectsRepo.branch'"
            sh 'git submodule update --init'
        }
        for (repo in projectsSubRepos) {
            if (repo.branch && !repo.branch.isAllWhitespace()) {
                sh "cd '$repo.path' && git checkout 'origin/$repo.branch'"
            }
        }

        for (repo in customRepos) {
            checkout(
                    $class: 'GitSCM',
                    userRemoteConfigs: [[url: repo.url, credentialsId: openmpfCustomRepoCredId]],
                    branches: [[name: repo.branch]],
                    extensions: [
                            [$class: 'CleanBeforeCheckout'],
                            [$class: 'GitLFSPull'],
                            [$class: 'RelativeTargetDirectory', relativeTargetDir: repo.path],
                            [$class: 'SubmoduleOption',
                                      disableSubmodules: false,
                                      parentCredentials: true,
                                      recursiveSubmodules: true,
                                      trackingSubmodules: false]])
        }

        for (repo in allRepos) {
            repo.sha = shOutput "cd $repo.path && git rev-parse HEAD"
        }
    } // stage('Clone repos')

    optionalStage('Check repos for updates', pollReposAndEndBuild) {
        echo 'CHANGES:'

        def requiresBuild = false

        for (repo in allRepos) {
            requiresBuild |= (repo.prevSha != repo.sha)
            echo "$repo.name: $repo.prevSha --> $repo.sha"
        }
        echo "REQUIRES BUILD: $requiresBuild"
        currentBuild.result = requiresBuild ? 'SUCCESS' : 'ABORTED';
    }

    if (pollReposAndEndBuild) {
        return // end build early; do this outside of a stage
    }

    optionalStage('Prune Docker', pruneDocker) {
         sh "docker system prune --all --force"
    }

    def componentComposeFiles
    def runtimeComposeFiles

    stage('Build images') {
    timeout(time: buildTimeout, unit: 'HOURS') {
        // Make sure we are using most recent version of external images
        for (externalImage in ['docker/dockerfile:1.2', 'postgres:alpine',
                               'redis:alpine', 'ubuntu:20.04']) {
            try {
                sh "docker pull '$externalImage'"
            }
            catch (e) {
                if (buildNoCache) {
                    throw e;
                }
                else {
                    echo "WARNING: Could not pull latest $externalImage from DockerHub."
                    e.printStackTrace()
                }
            }
        }

        if (preDockerBuildScriptPath) {
            sh preDockerBuildScriptPath
        }

        def noCacheArg = buildNoCache ? '--no-cache' : ''
        def commonBuildArgs = " --build-arg BUILD_TAG=$inProgressTag --build-arg BUILD_VERSION=$imageVersion " +
                "$noCacheArg "
        def labelArgs = getUserDefinedLabelArgs(imageUrl, imageVersion)
        def customLabelArg = getCustomLabelArg(customLabelKey)

        dir (openmpfDockerRepo.path) {
            sh 'docker build -f openmpf_build/Dockerfile .. --build-arg RUN_TESTS=true ' +
                    "$commonBuildArgs $labelArgs -t openmpf_build:$inProgressTag"

            // --no-cache needs to be handled differently for the openmpf_integration_tests image because it
            // expects that openmpf_build will populate the mvn_cache cache mount. When you run a
            // --no-cache build, Docker will clear any cache mounts used in the Dockerfile right before
            // beginning the build. If we were to just do a regular --no-cache build for openmpf_integration_tests,
            // the mvn_cache mount will be empty.
            if (buildNoCache) {
                // openmpf_integration_tests Dockerfile uses two stages. The final stage uses openmpf_build as the
                // base image, so the --no-cache build of openmpf_build invalidates the cache for that stage.
                // In order to invalidate the cache for the first stage (download_dependencies), we do a --no-cache
                // build with download_dependencies as the target
                sh 'docker build integration_tests --target download_dependencies --no-cache'
            }
            sh "docker build integration_tests $commonBuildArgs --no-cache=false " +
                    " -t openmpf_integration_tests:$inProgressTag"
        }

        if (buildCustomComponents) {
            sh "docker build $customSystemTestsRepo.path $commonBuildArgs $customLabelArg " +
                    " -t openmpf_integration_tests:$inProgressTag"
        }


        dir(openmpfDockerRepo.path + '/components') {
            def cppShas = getVcsRefLabelArg([openmpfCppSdkRepo])
            sh "docker build . -f cpp_component_build/Dockerfile $commonBuildArgs $labelArgs $cppShas " +
                    " -t openmpf_cpp_component_build:$inProgressTag"

            sh "docker build . -f cpp_executor/Dockerfile $commonBuildArgs $labelArgs $cppShas " +
                    " -t openmpf_cpp_executor:$inProgressTag"


            def javaShas = getVcsRefLabelArg([openmpfJavaSdkRepo])
            sh "docker build . -f java_component_build/Dockerfile $commonBuildArgs $labelArgs $javaShas " +
                    " -t openmpf_java_component_build:$inProgressTag"

            sh "docker build . -f java_executor/Dockerfile $commonBuildArgs $labelArgs $javaShas " +
                    " -t openmpf_java_executor:$inProgressTag"


            def pythonShas = getVcsRefLabelArg([openmpfPythonSdkRepo])
            sh "docker build . -f python/Dockerfile $commonBuildArgs $labelArgs $pythonShas " +
                    " --target ssb -t openmpf_python_executor_ssb:$inProgressTag"

            // Add --no-cache=false so openmpf_python_component_build and openmpf_python_executor
            // use the same common layers as openmpf_python_executor_ssb.
            // When a user requests a no-cache build, openmpf_python_executor_ssb will be
            // completely rebuilt. openmpf_python_component_build and openmpf_python_executor
            // will use the layers from the openmpf_python_executor_ssb that was just built with
            // --no-cache.
            sh "docker build . -f python/Dockerfile $commonBuildArgs $labelArgs $pythonShas " +
                    " --target build -t openmpf_python_component_build:$inProgressTag --no-cache=false"

            sh "docker build . -f python/Dockerfile $commonBuildArgs $labelArgs $pythonShas " +
                    " --target executor -t openmpf_python_executor:$inProgressTag --no-cache=false"
        }

        dir (openmpfDockerRepo.path) {
            sh 'cp .env.tpl .env'

            componentComposeFiles = 'docker-compose.components.yml'
            def customComponentServices = []

            if (buildCustomComponents) {
                def customComponentsComposeFile =
                        "../../$customComponentsRepo.path/docker-compose.custom-components.yml"
                componentComposeFiles += ":$customComponentsComposeFile"

                def customGpuOnlyComponentsComposeFile =
                            "../../$customComponentsRepo.path/docker-compose.custom-gpu-only-components.yml"
                componentComposeFiles += ":$customGpuOnlyComponentsComposeFile"

                customComponentServices =
                        readYaml(text: shOutput("cat $customComponentsComposeFile")).services.keySet()
                customComponentServices +=
                        readYaml(text: shOutput("cat $customGpuOnlyComponentsComposeFile")).services.keySet()
            }

            runtimeComposeFiles = "docker-compose.core.yml:$componentComposeFiles:docker-compose.elk.yml"

            withEnv(["TAG=$inProgressTag", "COMPOSE_FILE=$runtimeComposeFiles"]) {
                sh "docker compose build $commonBuildArgs --build-arg RUN_TESTS=true --parallel"

                def composeYaml = readYaml(text: shOutput('docker compose config'))
                addVcsRefLabels(composeYaml, openmpfRepo, openmpfDockerRepo)
                addUserDefinedLabels(composeYaml, customComponentServices, imageUrl, imageVersion, customLabelKey)
            }
        }

        if (applyCustomConfig) {
            echo 'APPLYING CUSTOM CONFIGURATION'
            dir(customConfigRepo.path) {
                def wfmShasArg = getVcsRefLabelArg([openmpfRepo, openmpfDockerRepo, customConfigRepo])
                sh "docker build workflow_manager $commonBuildArgs $customLabelArg $wfmShasArg " +
                        " -t openmpf_workflow_manager:$inProgressTag"
            }
        }
        else  {
            echo 'SKIPPING CUSTOM CONFIGURATION'
        }
    } // timeout
    } // stage('Build images')

    optionalStage('Run Integration Tests', !skipIntegrationTests) {
        dir(openmpfDockerRepo.path) {
            test_cli_runner(inProgressTag)

            def skipArgs = env.docker_services_build_only.split(',').collect{ it.replaceAll("\\s","") }.findAll{ !it.isEmpty() }.collect{ "--scale $it=0"  }.join(' ')
            def composeFiles = "docker-compose.integration.test.yml:$componentComposeFiles"

            def nproc = Math.min((shOutput('nproc') as int), 6)
            def servicesInSystemTests = ['ocv-face-detection', 'ocv-dnn-detection', 'oalpr-license-plate-text-detection',
                                         'mog-motion-detection', 'subsense-motion-detection',
                                         'east-text-detection', 'tesseract-ocr-text-detection', 'keyword-tagging']

            def scaleArgs = servicesInSystemTests.collect({ "--scale '$it=$nproc'" }).join(' ')
            // Sphinx uses a huge amount of memory so we don't want more than 2 of them.
            scaleArgs += " --scale sphinx-speech-detection=${Math.min(nproc, 2)} "

            withEnv(["TAG=$inProgressTag",
                     "EXTRA_MVN_OPTIONS=$mvnTestOptions",
                     // Use custom project name to allow multiple builds on same machine
                     "COMPOSE_PROJECT_NAME=openmpf_$buildId",
                     "COMPOSE_FILE=$composeFiles",
                     "ACTIVE_MQ_BROKER_URI=failover:(tcp://workflow-manager:61616)?maxReconnectAttempts=100&startupMaxReconnectAttempts=100"]) {
                try {
                    sh "docker compose up --exit-code-from workflow-manager $scaleArgs $skipArgs"
                    shStatus 'docker compose down --volumes'
                }
                catch (e) {
                    if (preserveContainersOnFailure) {
                        shStatus 'docker compose stop'
                    } else {
                        shStatus 'docker compose down --volumes'
                    }
                    throw e;
                }
                finally {
                    junit 'test-reports/*-reports/*.xml'
                }
            } // withEnv
        } // dir(openmpfDockerRepo.path)
    } // stage('Run Integration Tests')

    optionalStage('Trivy Scans', runTrivyScans) {
        def composeYaml
        dir (openmpfDockerRepo.path) {
            withEnv(["TAG=$inProgressTag",
                     "COMPOSE_FILE=docker-compose.core.yml:$componentComposeFiles"]) {
                composeYaml = readYaml(text: shOutput('docker compose config'))
            }
        }
        sh 'docker pull aquasec/trivy'
        def trivyVolume = "trivy_$inProgressTag"
        sh "docker volume create $trivyVolume"
        try {
            def failedImages = []
            for (def service in composeYaml.services.values()) {
                def exitCode = shStatus("docker run --rm " +
                        "-v /var/run/docker.sock:/var/run/docker.sock " +
                        "-v $trivyVolume:/root/.cache/ " +
                        "-v '${pwd()}/$openmpfDockerRepo.path/trivyignore.txt:/.trivyignore' " +
                        "aquasec/trivy image --severity CRITICAL,HIGH --exit-code 1 " +
                        "--timeout 30m --scanners vuln $service.image")
                if (exitCode != 0) {
                    failedImages << service.image
                }
            }
            if (failedImages) {
                echo 'Trivy scan failed for the following images:\n' + failedImages.join('\n')
            }
        }
        finally {
            sh "docker volume rm $trivyVolume"
        }
    }

    stage('Re-Tag Images') {
        reTagImages(inProgressTag, remoteImagePrefix, imageTag)
    }

    optionalStage('Push runtime images', pushRuntimeImages) {
        withEnv(["TAG=$imageTag", "REGISTRY=$remoteImagePrefix", "COMPOSE_FILE=$runtimeComposeFiles"]) {
            sh "docker push '${remoteImagePrefix}openmpf_cpp_component_build:$imageTag'"
            sh "docker push '${remoteImagePrefix}openmpf_cpp_executor:$imageTag'"

            sh "docker push '${remoteImagePrefix}openmpf_java_component_build:$imageTag'"
            sh "docker push '${remoteImagePrefix}openmpf_java_executor:$imageTag'"

            sh "docker push '${remoteImagePrefix}openmpf_python_component_build:$imageTag'"
            sh "docker push '${remoteImagePrefix}openmpf_python_executor:$imageTag'"
            sh "docker push '${remoteImagePrefix}openmpf_python_executor_ssb:$imageTag'"

            sh "cd '$openmpfDockerRepo.path' && docker compose push"
        } // withEnv...
    } // optionalStage('Push runtime images', ...
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
    else if (isProbableTimeout(buildException)) {
        echo 'DETECTED PROBABLE BUILD TIMEOUT'
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

    if (buildStatus != 'success') {
        // Re-tag images after failure so we don't end up with a bunch of images for every failed build.
        reTagImages(inProgressTag, '', 'failed-build-deleteme')
    }

    if (postBuildStatusEnabled && !skipIntegrationTests) {
        for (repo in projectsSubRepos) {
            postBuildStatus(repo, buildStatus, githubAuthToken)
        }
    }
    email(buildStatus, emailRecipients)

    dockerCleanUp()
}
} // wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm'])
} // node(env.jenkins_nodes)


def addVcsRefLabels(composeYaml, openmpfRepo, openmpfDockerRepo) {
    def commonVcsRefs = formatVcsRefs([openmpfRepo, openmpfDockerRepo])

    for (def serviceName in composeYaml.services.keySet()) {
        def service = composeYaml.services[serviceName]
        if (!service.build) {
            echo "Not labeling $service.image since we didn't build it"
            continue
        }

        // workflow-manager and markup have their build context within the openmpf-docker repo, but their content
        // is really based on the openmpf repo.
        if (serviceName == 'workflow-manager' || serviceName == 'markup') {
            addLabelToImage(service.image, 'org.label-schema.vcs-ref', commonVcsRefs)
            continue
        }
        if (serviceName == 'kibana') {
            prependImageLabel(service.image, 'org.label-schema.vcs-ref', formatVcsRefs([openmpfDockerRepo]))
            continue;
        }

        def contextDir = service.build.context
        def tld = shOutput "cd '$contextDir' && basename \$(git rev-parse --show-toplevel)"
        def sha = shOutput "cd '$contextDir' && git rev-parse HEAD"

        prependImageLabel(service.image, 'org.label-schema.vcs-ref', "$tld: $sha, $commonVcsRefs")
    }
}


def addLabelToImage(imageName, labelName, labelValue) {
    sh "echo 'FROM $imageName' | docker build - -t $imageName --label '$labelName=$labelValue'"
}

def prependImageLabel(imageName, labelName, labelValue) {
    def existingLabelValue = shOutput(
            /docker image inspect $imageName --format '{{index .Config.Labels "$labelName"}}'/)

    if (existingLabelValue) {
        labelValue += ", $existingLabelValue"
    }
    addLabelToImage(imageName, labelName, labelValue)
}

def formatVcsRefs(repos) {
    return repos.collect { "$it.name: $it.sha" }.join(', ');
}

def getVcsRefLabelArg(repos) {
    def shas = formatVcsRefs(repos)
    return " --label org.label-schema.vcs-ref='$shas'"
}


def addUserDefinedLabels(composeYaml, customComponentServices, imageUrl, imageVersion, customLabelKey) {
    def commonLabels = getUserDefinedLabels(imageUrl, imageVersion)
    def customLabels = getUserDefinedLabels(imageUrl, imageVersion, customLabelKey)

    for (def serviceName in composeYaml.services.keySet()) {
        def service = composeYaml.services[serviceName]
        if (!service.build) {
            echo "Not labeling $service.image since we didn't build it"
            continue
        }

        if (customComponentServices.contains(serviceName)) {
            addLabelsToImage(service.image, customLabels)
            continue
        }

        addLabelsToImage(service.image, commonLabels)
    }
}

def addLabelsToImage(imageName, labels) {
    if (!labels.isEmpty()) {
        def labelArgs = getLabelArgs(labels)
        sh "echo 'FROM $imageName' | docker build - -t $imageName $labelArgs"
    }
}

def getUserDefinedLabelArgs(imageUrl, imageVersion) {
    return getLabelArgs(getUserDefinedLabels(imageUrl, imageVersion))
}

def getCustomLabelArg(customLabelKey) {
    return getLabelArgs(getCustomLabel(customLabelKey))
}

def getLabelArgs(labels) {
    return labels.collect { "--label ${it.key}=${it.value}" }.join(' ')
}

def getUserDefinedLabels(imageUrl, imageVersion, customLabelKey) {
    return getUserDefinedLabels(imageUrl, imageVersion) << getCustomLabel(customLabelKey)
}

def getUserDefinedLabels(imageUrl, imageVersion) {
    def labels = [:]
    if (imageUrl) {
        labels["org.label-schema.url"] = imageUrl
    }
    if (imageVersion) {
        labels["org.label-schema.version"] = imageVersion
    }
    return labels
}

def getCustomLabel(customLabelKey) {
    return ["$customLabelKey": '']
}


def isAborted() {
    return currentBuild.result == 'ABORTED' ||
            !currentBuild.getRawBuild().getActions(jenkins.model.InterruptedBuildAction).isEmpty()
}

def isProbableTimeout(Exception e) {
    return e.getClass() == org.jenkinsci.plugins.workflow.steps.FlowInterruptedException
}

def postBuildStatus(repo, status, githubAuthToken) {
    if (!repo.branch || repo.branch.isAllWhitespace()) {
        return
    }

    def description = "$currentBuild.projectName $currentBuild.displayName"
    def statusJson = /{ "state": "$status", "description": "$description", "context": "jenkins" }/
    def url = "https://api.github.com/repos/openmpf/$repo.name/statuses/$repo.sha"
    def response = shOutput "curl -s -X POST -H 'Authorization: token $githubAuthToken' -d '$statusJson' $url"

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


def reTagImages(inProgressTag, remoteImagePrefix, imageTag) {
    def imageNames = shOutput("docker images 'openmpf_*:$inProgressTag' --format '{{.Repository}}'").split('\n')

    for (def imageName: imageNames) {
        def inProgressName = "$imageName:$inProgressTag"
        def finalName = "${remoteImagePrefix}${imageName}:$imageTag"
        sh "docker tag $inProgressName $finalName"
        // When an image has multiple tags `docker image rm` only removes the specified tag
        sh "docker image rm $inProgressName"
    }
}


def dockerCleanUp() {
    try {
        def daysUntilRemoval = 7
        def hoursUntilRemoval = daysUntilRemoval * 24
        // Remove dangling <none> images that are more than 1 week old.
        sh "docker image prune --force --filter 'until=${hoursUntilRemoval}h'"

        echo "Checking for deleteme images older than $daysUntilRemoval days."

        def images = shOutput("docker images --filter 'dangling=false' --format '{{.Repository}}:{{.Tag}}'")\
                        .split("\n")

        def now = java.time.Instant.now()
        for (image in images) {
            if (!image.contains('deleteme')) {
                continue;
            }

            // Time formats from Docker (includes quotes at beginning and end):
            // - "2019-11-18T18:58:33.990718123Z"
            // - "2020-06-29T12:47:45.512019992-04:00"
            def quotedTagTimeString = shOutput "docker image inspect --format '{{json .Metadata.LastTagTime}}' $image"
            def tagTimeString = quotedTagTimeString[1..-2]
            def tagTime = parseDate(tagTimeString)

            def daysSinceLastTag = tagTime.until(now, java.time.temporal.ChronoUnit.DAYS)
            if (daysSinceLastTag > daysUntilRemoval) {
                echo "Deleting $image because has \"deleteme\" in its name and was last tagged $daysSinceLastTag days ago."
                sh "docker image rm $image"
            }
        }

        sh 'docker builder prune --force --keep-storage=120GB'
    }
    catch (e) {
        echo "Docker clean up failed due to: $e"
    }
}


def test_cli_runner(inProgressTag) {
    sh "docker build components/cli_runner/tests -t openmpf_cli_runner_tests:$inProgressTag"

    sh "docker run --rm --env TEST_IMG_TAG=$inProgressTag --volume /var/run/docker.sock:/var/run/docker.sock " +
            " openmpf_cli_runner_tests:$inProgressTag"
}


// Need @NonCPS because DateTimeFormatter is not serizalizable
@NonCPS
def parseDate(dateString) {
    def timestampFormatter =
            java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME.withZone(
            java.time.ZoneId.systemDefault());

    return java.time.Instant.from(timestampFormatter.parse(dateString))
}

def shOutput(script) {
    return sh(script: script, returnStdout: true).trim()
}

def shStatus(script) {
    // This will not throw an exception for a non-zero exit code.
    return sh(script: script, returnStatus: true)
}

def optionalStage(name, condition, body) {
    if (condition) {
        stage (name, body);
    }
    else {
        stage(name) {
            echo "SKIPPING STAGE: $name"
            org.jenkinsci.plugins.pipeline.modeldefinition.Utils.markStageSkippedForConditional(name)
        }
    }
}
