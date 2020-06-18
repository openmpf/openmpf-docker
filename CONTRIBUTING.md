# Build your own OpenMPF Component with Docker

Please refer to the [OpenMPF Component
Documentation](https://openmpf.github.io/docs/site/Component-API-Overview/index.html)
for information on how to implement your component. Please refer to the
README for either the 
[C++ component base image](components/cpp_executor/README.md), 
the [Python component base image](components/python_executor/README.md), or the 
[Java component base image](components/java_executor/README.md) 
for instructions for creating your component's Dockerfile. Also, please refer 
to the 
[OpenMPF Contributor Guide](https://openmpf.github.io/docs/site/Contributor-Guide/index.html) 
for information on contributing your work to the open source repositories. In 
this guide we will explain the process of integrating your component code into 
a Docker build and how to run it as part of a Docker deployment.

Follow the steps in the [README](README.md#getting-started) to build and run a
single-host Docker deployment before attempting to integrate your component.
That way, if the deployment is not successful, you can be sure it's not an issue
related to your code.

Your component code should be contained within a single directory that shares
your component name. If not already there, place this directory within the
appropriate language-specific directory (e.g. `cpp`, `java`, `python`) that
exists within the `openmpf-projects/openmpf-components` or
`openmpf-projects/openmpf-contrib-components` directories. Next, add an entry to
`docker-compose.components.yml` for your component. Next, re-generate your
`docker-compose.yml` file following the steps from the 
["Generate docker-compose.yml" section of the README.](README.md#generate-docker-composeyml)

Next, run `docker-compose build` from within the `openmpf-docker` directory to 
build your component's Docker image along with the rest of OpenMPF.
Then, run the steps in the
[Run OpenMPF using Docker Compose](README.md#run-openmpf-using-docker-compose)
section to deploy them. Repeat these steps, starting with the 
`docker-compose build` command, each time you make a change to your 
component code and want to run it.

