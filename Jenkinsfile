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

// Jenkins Global Variables Reference: https://opensource.triology.de/jenkins/pipeline-syntax/globals

// Get build parameters.
def imageTag = env.getProperty("image_tag")
def emailRecipients = env.getProperty("email_recipients")

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
def runGTests = env.getProperty("run_gtests").toBoolean()
def runMvnTests = env.getProperty("run_mvn_tests").toBoolean()
def mvnTestOptions = env.getProperty("mvn_test_options")
def buildRuntimeImages = env.getProperty("build_runtime_images").toBoolean()
def buildNoCache = env.getProperty("build_no_cache")?.toBoolean() ?: false
def pushRuntimeImages = env.getProperty("push_runtime_images").toBoolean()
def pollReposAndEndBuild = env.getProperty("poll_repos_and_end_build")?.toBoolean() ?: false

def dockerRegistryHost = env.getProperty("docker_registry_host")
def dockerRegistryPort = env.getProperty("docker_registry_port")
def dockerRegistryPath = env.getProperty("docker_registry_path") ?: "/openmpf"
def dockerRegistryCredId = env.getProperty("docker_registry_cred_id")
def jenkinsNodes = env.getProperty("jenkins_nodes")
def extraTestDataPath = env.getProperty("extra_test_data_path")
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

// These properties are for posting the Jenkins build status to GitHub
def postOpenmpfDockerBuildStatus = env.getProperty("post_openmpf_docker_build_status").toBoolean()
def githubAuthToken = env.getProperty("github_auth_token")

// Labels
def buildDate
def buildShas

// Repos
def allRepos = []
def coreRepos = []
def customComponentRepos = []
def openmpfDockerRepo
def customConfigRepo

// Tests
def gTestsRetval = -1
def mvnTestsRetval = -1

class Repo {
    def script // need this to call global methods
    def name
    def url
    def path
    def branch
    def credId
    def oldSha
    def newSha

    Repo(script, name, url, path, branch) {
        this.script = script
        this.name = name
        this.url = url
        this.path = path
        this.branch = branch
    }

    Repo(script, name, url, path, branch, credId) {
        this(script, name, url, path, branch)
        this.credId = credId
    }

    // Cannot call this method within constructor due to https://issues.jenkins-ci.org/browse/JENKINS-26313
    def getGitCommitSha() {
        this.oldSha = script.getGitCommitSha(path)
    }

    def gitCheckoutAndPull() {
        if (credId) {
            this.newSha = script.gitCheckoutAndPullWithCredId(url, credId, path, branch)
        } else {
            this.newSha = script.gitCheckoutAndPull(url, path, branch)
        }
    }

    def postBuildStatus(buildStatus, authToken) {
        script.postBuildStatus(name, branch, newSha, buildStatus, authToken)
    }
}

def script = this // instance of the Groovy script

node(jenkinsNodes) {
wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console
    def buildException

    // Rename the named volumes and networks to be unique to this Jenkins build pipeline
    def buildSharedDataVolumeSuffix = 'shared_data_' + currentBuild.projectName
    def buildSharedDataVolume = 'openmpf_' + buildSharedDataVolumeSuffix

    def buildDbDataVolumeSuffix = 'db_data_' + currentBuild.projectName
    def buildDbDataVolume = 'openmpf_' + buildDbDataVolumeSuffix

    def buildNetworkSuffix = 'overlay_' + currentBuild.projectName
    def buildNetwork = 'openmpf_' + buildNetworkSuffix

    try {
        buildDate = getTimestamp()

        // Clean up last run
        sh 'docker volume rm -f ' + buildSharedDataVolume + ' ' + buildDbDataVolume
        removeDockerNetwork(buildNetwork)

        // Revert changes made to files by a previous Jenkins build
        if (fileExists('.git')) {
            sh 'git reset --hard HEAD'
        }

        def dockerRegistryHostAndPort = dockerRegistryHost
        if (dockerRegistryPort) {
            dockerRegistryHostAndPort += ':' + dockerRegistryPort
        }

        def remoteImageTagPrefix = dockerRegistryHostAndPort
        if (dockerRegistryPath) {
            if (!dockerRegistryPath.startsWith("/")) {
                remoteImageTagPrefix += "/"
            }
            remoteImageTagPrefix += dockerRegistryPath
            if (!dockerRegistryPath.endsWith("/")) {
                remoteImageTagPrefix += "/"
            }
        }

        def buildImageName = remoteImageTagPrefix + 'openmpf_build:' + imageTag
        def buildContainerId

        def workflowManagerImageName = remoteImageTagPrefix + 'openmpf_workflow_manager:' + imageTag
        def activeMqImageName = remoteImageTagPrefix + 'openmpf_active_mq:' + imageTag
        def pythonExecutorImageName = remoteImageTagPrefix + 'openmpf_python_executor:' + imageTag

        def openmpfGitHubUrl = 'https://github.com/openmpf'
        def openmpfProjectsPath = 'openmpf_build/openmpf-projects'

        stage('Clone repos') {
            // Define repos
            openmpfDockerRepo = new Repo(script, 'openmpf-docker', openmpfGitHubUrl + '/openmpf-docker.git',
                    '.', openmpfDockerBranch)
            allRepos.add(openmpfDockerRepo)

            coreRepos.add(new Repo(script, 'openmpf', openmpfGitHubUrl + '/openmpf.git',
                    openmpfProjectsPath + '/openmpf', openmpfBranch))
            coreRepos.add(new Repo(script, 'openmpf-components', openmpfGitHubUrl + '/openmpf-components.git',
                    openmpfProjectsPath + '/openmpf-components', openmpfComponentsBranch))
            coreRepos.add(new Repo(script, 'openmpf-contrib-components', openmpfGitHubUrl + '/openmpf-contrib-components.git',
                    openmpfProjectsPath + '/openmpf-contrib-components', openmpfContribComponentsBranch))
            coreRepos.add(new Repo(script, 'openmpf-cpp-component-sdk', openmpfGitHubUrl + '/openmpf-cpp-component-sdk.git',
                    openmpfProjectsPath + '/openmpf-cpp-component-sdk', openmpfCppComponentSdkBranch))
            coreRepos.add(new Repo(script, 'openmpf-java-component-sdk', openmpfGitHubUrl + '/openmpf-java-component-sdk.git',
                    openmpfProjectsPath + '/openmpf-java-component-sdk', openmpfJavaComponentSdkBranch))
            coreRepos.add(new Repo(script, 'openmpf-python-component-sdk', openmpfGitHubUrl + '/openmpf-python-component-sdk.git',
                    openmpfProjectsPath + '/openmpf-python-component-sdk', openmpfPythonComponentSdkBranch))
            coreRepos.add(new Repo(script, 'openmpf-build-tools', openmpfGitHubUrl + '/openmpf-build-tools.git',
                    openmpfProjectsPath + '/openmpf-build-tools', openmpfBuildToolsBranch))
            allRepos.addAll(coreRepos)

            // Get old SHAs
            openmpfDockerRepo.getGitCommitSha()

            for (repo in coreRepos) {
                repo.getGitCommitSha()
            }

            // Pull and get new SHAs

            openmpfDockerRepo.gitCheckoutAndPull() // do this first since other repos are cloned into this repo's path

            gitCheckoutAndPull('https://github.com/openmpf/openmpf-projects.git', openmpfProjectsPath, openmpfProjectsBranch)
            sh 'cd ' + openmpfProjectsPath + '; git submodule update --init'

            for (repo in coreRepos) {
                repo.gitCheckoutAndPull()
            }

            if (buildCustomComponents) {
                // Define repos
                customComponentRepos.add(new Repo(script, 'openmpf-custom-docker', openmpfCustomDockerRepo,
                        'openmpf_custom_build', openmpfCustomDockerBranch, openmpfCustomRepoCredId))
                customComponentRepos.add(new Repo(script, 'openmpf-custom-components', openmpfCustomComponentsRepo,
                        openmpfProjectsPath + '/' + openmpfCustomComponentsSlug, openmpfCustomComponentsBranch, openmpfCustomRepoCredId))
                customComponentRepos.add(new Repo(script, 'openmpf-custom-system-tests', openmpfCustomSystemTestsRepo,
                        openmpfProjectsPath + '/' + openmpfCustomSystemTestsSlug, openmpfCustomSystemTestsBranch, openmpfCustomRepoCredId))
                allRepos.addAll(customComponentRepos)

                // Get old SHAs
                for (repo in customComponentRepos) {
                    repo.getGitCommitSha()
                }

                // Pull and get new SHAs
                for (repo in customComponentRepos) {
                    repo.gitCheckoutAndPull()
                }
            }

            if (applyCustomConfig) {
                // Define repo
                customConfigRepo = new Repo(script, 'openmpf-custom-config', openmpfConfigDockerRepo,
                        'openmpf_custom_config', openmpfConfigDockerBranch, openmpfConfigRepoCredId)
                allRepos.add(customConfigRepo)

                // Get old SHA
                customConfigRepo.getGitCommitSha()

                // Pull and get new SHA
                customConfigRepo.gitCheckoutAndPull()
            }
        }

        stage('Check repos for updates') {
            if (!pollReposAndEndBuild) {
                echo 'SKIPPING REPO UPDATE CHECK'
            }
            when(pollReposAndEndBuild) { // if false, don't show this step in the Stage View UI
                println 'CHANGES:'

                requiresBuild = false
                for (repo in allRepos) {
                    oldSha = repo.oldSha
                    newSha = repo.newSha
                    requiresBuild |= (oldSha != newSha)
                    if (oldSha) {
                        println repo.name + ':\n\t ' + oldSha + ' --> ' + newSha
                    } else {
                        println repo.name + ':\n\t ' + newSha
                    }
                }

                println 'REQUIRES BUILD: ' + requiresBuild

                if (requiresBuild) {
                    currentBuild.result = 'SUCCESS'
                } else {
                    currentBuild.result = 'ABORTED'
                }
            }
        }

        if (pollReposAndEndBuild) {
            return // end build early; do this outside of a stage
        }

        docker.withRegistry('http://' + dockerRegistryHostAndPort, dockerRegistryCredId) {

            stage('Build base image') {
                // Copy JDK into place
                sh 'cp -u /data/openmpf/jdk-*-linux-x64.rpm openmpf_build'

                // Copy *package.json into place
                if (buildPackageJson.contains("/")) {
                    sh 'cp ' + buildPackageJson + ' ' + openmpfProjectsPath +
                            '/openmpf/trunk/jenkins/scripts/config_files'
                    buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/") + 1)
                }

                // Generate compose file
                def dockerComposeConfigCommand = 'OPENMPF_PROJECTS_PATH=' + openmpfProjectsPath +
                        ' REGISTRY=' + remoteImageTagPrefix + ' TAG=' + imageTag +
                        ' docker-compose' +
                        ' -f docker-compose.core.yml' +
                        ' -f docker-compose.components.yml'

                if (buildCustomComponents) {
                    dockerComposeConfigCommand += ' -f openmpf_custom_build/docker-compose.custom-components.yml'
                }

                dockerComposeConfigCommand += ' config > docker-compose.yml'

                sh 'cp .env.tpl .env'
                sh "${dockerComposeConfigCommand}"

                // DEBUG
                // Add RUN_TESTS to node-manager
                sh 'cat docker-compose.yml | docker run --rm -i mikefarah/yq' +
                        ' yq w - --tag \'!!str\' services.node_manager.environment.RUN_TESTS true'
                sh 'exit 1'

                // TODO: Attempt to pull images in separate stage so that they are not
                // built from scratch on a clean Jenkins node.

                buildShas = 'openmpf-docker: ' + openmpfDockerRepo.newSha
                buildShas += ', ' + getBuildShasStr(coreRepos)

                sh 'docker build openmpf_build/' +
                        (buildNoCache ? ' --no-cache' : '' ) +
                        ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                        ' --build-arg BUILD_TAG=' + imageTag +
                        ' --build-arg BUILD_DATE=' + buildDate +
                        ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                        ' -t ' + buildImageName

                if (buildCustomComponents) {
                    // Copy custom component build files into place (SDKs, etc.)
                    sh 'cp -u /data/openmpf/custom-build-files/* openmpf_custom_build'

                    buildShas += ', ' + getBuildShasStr(customComponentRepos)

                    // Build the new build image for custom components using the original build image for open source
                    // components. This overwrites the original build image tag.
                    sh 'docker build openmpf_custom_build/' +
                            (buildNoCache ? ' --no-cache' : '' ) +
                            ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                            ' --build-arg BUILD_TAG=' + imageTag +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                            ' -t ' + buildImageName
                }
            }

            try {
                stage('Build OpenMPF') {
                    if (!buildOpenmpf) {
                        echo 'SKIPPING OPENMPF BUILD'
                    }
                    when (buildOpenmpf) { // if false, don't show this step in the Stage View UI
                        if (runMvnTests) {
                            sh 'docker network create ' + buildNetwork
                        }

                        // Run container as daemon in background.
                        buildContainerId = sh(script: 'docker run --rm --entrypoint sleep -t -d ' +
                                '--name workflow_manager ' +
                                '-p 20160:20160 ' +
                                '--mount type=bind,source=/home/jenkins/.m2,target=/root/.m2 ' +
                                '--mount type=bind,source="$(pwd)"/openmpf_runtime/build_artifacts,target=/mnt/build_artifacts ' +
                                '--mount type=bind,source="$(pwd)"/openmpf_build/openmpf-projects,target=/mnt/openmpf-projects ' +
                                (runMvnTests ? '--mount type=volume,source=' + buildSharedDataVolume +  ',target=/home/mpf/openmpf-projects/openmpf/trunk/install/share ' : '') +
                                (runMvnTests ? '--mount type=bind,source=' + extraTestDataPath + ',target=/mpfdata,readonly ' : '') +
                                (runMvnTests ? '--network=' + buildNetwork +  ' ' : '') +
                                buildImageName + ' infinity', returnStdout: true).trim()

                        sh 'docker exec ' +
                                '-e BUILD_PACKAGE_JSON=' + buildPackageJson + ' ' +
                                buildContainerId + ' /home/mpf/docker-entrypoint.sh'
                    }
                }

                stage('Run Google tests') {
                    if (!runGTests) {
                        echo 'SKIPPING GOOGLE TESTS'
                    }
                    when (runGTests) { // if false, don't show this step in the Stage View UI
                        gTestsRetval = sh(script: 'docker exec ' +
                                buildContainerId + ' /home/mpf/run-gtests.sh', returnStatus: true)

                        processTestReports()

                        if (gTestsRetval != 0) {
                            sh 'exit ' + gTestsRetval
                        }
                    }
                }

                stage('Build runtime images') {
                    if (!buildRuntimeImages) {
                        echo 'SKIPPING BUILD OF RUNTIME IMAGES'
                    }
                    when (buildRuntimeImages) { // if false, don't show this step in the Stage View UI
                        sh 'DOCKER_BUILDKIT=1 docker build openmpf_runtime' +
                                ' --file openmpf_runtime/python_executor/Dockerfile ' +
                                (buildNoCache ? ' --no-cache' : '' ) +
                                ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                                ' --build-arg BUILD_TAG=' + imageTag +
                                ' --build-arg BUILD_DATE=' + buildDate +
                                ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                                " -t '${pythonExecutorImageName}'"

                        sh 'docker-compose build' +
                                (buildNoCache ? ' --no-cache' : '' ) +
                                ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                                ' --build-arg BUILD_TAG=' + imageTag +
                                ' --build-arg BUILD_DATE=' + buildDate +
                                ' --build-arg BUILD_SHAS=\"' + buildShas + '\"'
                    }
                }

                stage('Run Maven tests') {
                    if (!buildOpenmpf || !buildRuntimeImages || !runMvnTests) {
                        echo 'SKIPPING MAVEN TESTS'
                    }
                    when (buildOpenmpf && buildRuntimeImages && runMvnTests) { // if false, don't show this step in the Stage View UI
                        // Add extra test data volume
                        sh 'sed \'/shared_data:\\/opt\\/mpf\\/share:rw/a \\    - ' + extraTestDataPath + ':/mpfdata:ro\'' +
                                ' docker-compose.yml > docker-compose-test.yml'

                        // Update volume and network names
                        sh 'sed -i \'s/shared_data:/' + buildSharedDataVolumeSuffix + ':/g\' docker-compose-test.yml'
                        sh 'sed -i \'s/db_data:/' + buildDbDataVolumeSuffix + ':/g\' docker-compose-test.yml'
                        sh 'sed -i \'s/overlay/' + buildNetworkSuffix + '/g\' docker-compose-test.yml'

                        // To prevent conflicts with other concurrent builds, don't expose any ports
                        sh 'sed -i "/^.*ports:.*/d" docker-compose-test.yml'
                        sh 'sed -i "/^.*published:.*/d" docker-compose-test.yml'
                        sh 'sed -i "/^.*target:.*/d" docker-compose-test.yml'

                        // Add RUN_TESTS to node-manager
                        sh 'cat docker-compose-test.yml | docker run --rm -i mikefarah/yq' +
                                ' yq w - services.node_manager.environment.RUN_TESTS \'true\' > tmp.yml'
                        sh 'mv tmp.yml docker-compose-test.yml'

                        // Run supporting containers in background.
                        sh 'docker-compose -f docker-compose-test.yml up -d' +
                                ' --scale workflow_manager=0'

                        mvnTestsRetval = sh(script: 'docker exec' +
                                ' -e EXTRA_MVN_OPTIONS=\"' + mvnTestOptions + '\" ' +
                                buildContainerId +
                                ' /home/mpf/run-mvn-tests.sh', returnStatus: true)

                        processTestReports()

                        if (mvnTestsRetval != 0) {
                            sh 'exit ' + mvnTestsRetval
                        }
                    }
                }

            } finally {
                if (buildContainerId != null) {
                    sh 'docker container rm -f ' + buildContainerId

                    if (runMvnTests) {

                        if (fileExists('docker-compose-test.yml')) {
                            sh 'docker-compose -f docker-compose-test.yml rm -svf || true'
                            sh 'sleep 10' // give previous command some time
                        }

                        sh 'docker volume rm -f ' + buildDbDataVolume // preserve openmpf_shared_data for post-run analysis
                        removeDockerNetwork(buildNetwork)
                    }

                    // Remove dangling <none> images.
                    sh 'docker image prune -f'
                }
            }

            stage('Apply custom config') {
                if (!applyCustomConfig) {
                    echo 'SKIPPING CUSTOM CONFIGURATION'
                }
                when (applyCustomConfig) { // if false, don't show this step in the Stage View UI
                    buildShas += ', openmpf-custom-config: ' + customConfigRepo.newSha

                    // Build and tag the new Workflow Manager image with the image tag used in the compose files.
                    // That way, we do not have to modify the compose files. This overwrites the tag that referred
                    // to the original Workflow Manager image without the custom config.
                    sh 'docker build openmpf_custom_config/workflow_manager' +
                            (buildNoCache ? ' --no-cache' : '' ) +
                            ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                            ' --build-arg BUILD_TAG=' + imageTag +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                            ' -t ' + workflowManagerImageName

                    // Build and tag the new ActiveMQ image with the image tag used in the compose files.
                    sh 'docker build openmpf_custom_config/active_mq' +
                            (buildNoCache ? ' --no-cache' : '' ) +
                            ' --build-arg BUILD_REGISTRY=' + remoteImageTagPrefix +
                            ' --build-arg BUILD_TAG=' + imageTag +
                            ' --build-arg BUILD_DATE=' + buildDate +
                            ' --build-arg BUILD_SHAS=\"' + buildShas + '\"' +
                            ' -t ' + activeMqImageName
                }
            }

            stage('Push runtime images') {
                if (!pushRuntimeImages) {
                    echo 'SKIPPING PUSH OF RUNTIME IMAGES'
                }
                when (pushRuntimeImages) { // if false, don't show this step in the Stage View UI
                    // Pushing multiple tags is cheap, as all the layers are reused.
                    sh 'docker push ' + buildImageName
                    sh 'docker-compose push'
                    sh "docker push '${pythonExecutorImageName}'"
                }
            }

        } // end docker.withRegistry()
    } catch (Exception e) {
        buildException = e
    }

    def buildStatus
    if (isAborted()) {
        echo 'DETECTED BUILD ABORTED'
        buildStatus = "aborted"
    } else {
        if (buildException != null) {
            echo 'DETECTED BUILD FAILURE'
            echo 'Exception type: ' + buildException.getClass()
            echo 'Exception message: ' + buildException.getMessage()
            buildStatus = "failure"
        } else {
            echo 'DETECTED BUILD COMPLETED'
            echo "CURRENT BUILD RESULT: ${currentBuild.currentResult}"
            buildStatus = currentBuild.currentResult.equals("SUCCESS") ? "success" : "failure"
        }
        // Post build status
        def skipStatusPostReason = ''
        if (buildStatus == "success") {
            if (gTestsRetval == -1) {
                skipStatusPostReason += ' gtests not run.'
            }
            if (mvnTestsRetval == -1) {
                skipStatusPostReason += ' Maven tests not run.'
            }
        }
        if (!skipStatusPostReason.isEmpty()) {
            echo "SKIPPING POST OF BUILD STATUS:${skipStatusPostReason}"
        } else {
            if (postOpenmpfDockerBuildStatus) {
                openmpfDockerRepo.postBuildStatus(buildStatus, githubAuthToken)
            }
            for (repo in coreRepos) {
                repo.postBuildStatus(buildStatus, githubAuthToken)
            }
        }
    }

    email(buildStatus, emailRecipients)

    if (buildException != null) {
        throw buildException // rethrow so Jenkins knows of failure
    }
}}

def gitCheckoutAndPull(url, dir, branch) {
    // This is the official procedure, but we don't want all of the "Git Build Data"
    // entries clogging up the sidebar in the build UI:
    // checkout([$class: 'GitSCM',
    //    branches: [[name: '*/' + branch]],
    //    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: dir]],
    //    userRemoteConfigs: [[url: url]]])

    if (!branch.isEmpty()) {
        if (!fileExists(dir + '/.git')) {
            sh 'git clone ' + url + ' ' + dir
        }
        sh 'cd ' + dir + '; git fetch'
        sh 'cd ' + dir + '; git checkout ' + branch
        sh 'cd ' + dir + '; git pull origin ' + branch
    }

    return getGitCommitSha(dir) // assume the repo is already cloned
}

def gitCheckoutAndPullWithCredId(url, credId, dir, branch) {
    if (!branch.isEmpty()) {
        def scmVars = checkout([$class: 'GitSCM',
                  branches: [[name: branch]],
                  extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: dir]],
                  userRemoteConfigs: [[credentialsId: credId, url: url]]])

        // TODO: Make sure we're not in a detached state.
        // sh 'cd ' + dir + '; git checkout ' + branch

        return scmVars.GIT_COMMIT
    }

    return getGitCommitSha(dir) // assume the repo is already cloned
}

def getGitCommitSha(dir) {
    if (fileExists(dir + '/.git')) {
        return sh(script: 'cd ' + dir + '; git rev-parse HEAD', returnStdout: true).trim()
    }
    return ''
}

def isAborted() {
    return currentBuild.result.equals('ABORTED') ||
            !currentBuild.getRawBuild().getActions(jenkins.model.InterruptedBuildAction).isEmpty()
}

def email(status, recipients) {
    emailext (
            subject: status.toUpperCase() + ": ${env.JOB_NAME} [${env.BUILD_NUMBER}]",
            // mimeType: 'text/html',
            // body: "<p>Check console output at <a href=\"${env.BUILD_URL}\">${env.BUILD_URL}</a></p>",
            body: '${JELLY_SCRIPT,template="text"}',
            recipientProviders: [[$class: 'RequesterRecipientProvider']],
            to: recipients
    )
}

def getTimestamp() {
    return sh(script: 'date --iso-8601=seconds', returnStdout: true).trim()
}

def processTestReports() {
    def newReportsPath = 'openmpf_runtime/build_artifacts/reports'
    def processedReportsPath = newReportsPath + '/processed'

    // Touch files to avoid the following error if the test reports are more than 3 seconds old:
    // "Test reports were found but none of them are new"
    sh 'touch ' + newReportsPath + '/*-reports/*.xml'

    junit newReportsPath + '/*-reports/*.xml'

    sh 'mkdir -p ' + processedReportsPath
    sh 'mv ' + newReportsPath + '/*-reports' + ' ' + processedReportsPath
}

def postBuildStatus(repo, branch, sha, status, authToken) {
    if (branch.isEmpty()) {
        return
    }

    def resultJson = sh(script: 'echo \'{"state": "' + status + '", ' +
            '"description": "' + currentBuild.projectName + ' ' + currentBuild.displayName + '", ' +
            '"context": "jenkins"}\' | ' +
            'curl -s -X POST -H "Authorization: token ' + authToken + '" ' +
            '-d @- https://api.github.com/repos/openmpf/' + repo + '/statuses/' + sha, returnStdout: true)

    def success = resultJson.contains("\"state\": \"" + status + "\"") &&
            resultJson.contains("\"description\": \"" + currentBuild.projectName + ' ' + currentBuild.displayName + "\"") &&
            resultJson.contains("\"context\": \"jenkins\"")

    if (!success) {
        echo 'Failed to post build status:'
        echo resultJson
    }
}

def removeDockerNetwork(network) {
    if (sh(script: 'docker network inspect ' + network + ' > /dev/null 2>&1', returnStatus: true) == 0) {
        sh 'docker network rm ' + network
    }
}

def getBuildShasStr(repos) {
    buildShas = ''
    for (repo in repos) {
        if (!buildShas.isEmpty()) {
            buildShas += ', '
        }
        buildShas += repo.name + ': ' + repo.newSha
    }
    return buildShas
}
