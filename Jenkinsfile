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


node(env.jenkins_nodes) {
wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) { // show color in Jenkins console
    stage('Clone repos') {
        if (!fileExists('openmpf-projects')) {
            sh 'git clone --recurse-submodules https://github.com/openmpf/openmpf-projects.git'
        }
        sh """
            cd openmpf-projects
            git clean -ffd
            git submodule foreach git clean -ffd

            git fetch
            git checkout 'origin/$openmpfProjectsBranch'

            cd openmpf
            git checkout 'origin/$openmpfBranch'

            cd ../openmpf-components
            git checkout 'origin/$openmpfComponentsBranch'

            cd ../openmpf-contrib-components
            git checkout 'origin/$openmpfContribComponentsBranch'

            cd ../openmpf-cpp-component-sdk
            git checkout 'origin/$openmpfCppComponentSdkBranch'

            cd ../openmpf-java-component-sdk
            git checkout 'origin/$openmpfJavaComponentSdkBranch'

            cd ../openmpf-python-component-sdk
            git checkout 'origin/$openmpfPythonComponentSdkBranch'
            
            cd ../openmpf-build-tools
            git checkout 'origin/$openmpfBuildToolsBranch'
        """

        if (!fileExists('openmpf-docker')) {
            sh 'git clone https://github.com/openmpf/openmpf-docker.git'
        }
        sh """
            cd openmpf-docker
            git clean -ffd
            git fetch
            git checkout 'origin/$openmpfDockerBranch'
        """
    } // stage('Clone repos')

    stage('Build images') {
        if (buildPackageJson.contains('/')) {
            sh "cp $buildPackageJson openmpf-projects/openmpf/trunk/jenkins/scripts/config_files"
            buildPackageJson = buildPackageJson.substring(buildPackageJson.lastIndexOf("/")) + 1
        }
        withEnv(['DOCKER_BUILDKIT=1', 'RUN_TESTS=true']) {
            dir ('openmpf-docker') {
                sh 'docker build -f openmpf_build/Dockerfile ../openmpf-projects --build-arg RUN_TESTS ' +
                        "--build-arg BUILD_PACKAGE_JSON=$buildPackageJson  -t openmpf_build:$imageTag"

                sh "docker build workflow_manager -t openmpf_workflow_manager:$imageTag"

                sh "docker build node_manager -t openmpf_node_manager:$imageTag"

                sh "docker build integration_tests -t openmpf_integration_tests:$imageTag"
            }


            dir('openmpf-docker/components') {
                sh "docker build . -f cpp_component_build/Dockerfile -t openmpf_cpp_component_build:$imageTag"

                sh "docker build . -f cpp_executor/Dockerfile -t openmpf_cpp_executor:$imageTag"

                sh "docker build . -f python_executor/Dockerfile -t openmpf_python_executor:$imageTag"
            }


            dir('openmpf-projects/openmpf-components') {
                sh "docker build cpp/OcvFaceDetection --build-arg RUN_TESTS -t openmpf_ocv_face_detection:$imageTag"

                sh 'docker build cpp/TesseractOCRTextDetection --build-arg RUN_TESTS ' +
                        "-t openmpf_tesseract_ocr_text_detection:$imageTag"

                sh "docker build python/EastTextDetection -t openmpf_east_text_detection:$imageTag"

            }
        }
    } // stage('Build images')
} // wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm'])
} // node(env.jenkins_nodes)
