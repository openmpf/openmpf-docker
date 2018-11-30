# Build your own OpenMPF Component with Docker

Please refer to the [OpenMPF Component
Documentation](https://openmpf.github.io/docs/site/Component-API-Overview/index.html)
for information on how to implement your component, and the [OpenMPF Contributor
Guide](https://openmpf.github.io/docs/site/Contributor-Guide/index.html) for
information on contributing your work to the open source repositories. In this
section we will explain the process of integrating your component code into a
Docker build and how to run it as part of a Docker deployment.

Follow the steps in the [README](README.md#getting-started) to build and run a
single-host Docker deployment before attempting to integrate your component.
That way, if the deployment is not successful, you can be sure it's not an issue
related to your code.

Your component code should be contained within a single directory that shares
your component name. If not already there, place this directory within the
appropriate language-specific directory (e.g. `cpp`, `java`, `python`) that
exists within the `openmpf-projects/openmpf-components` or
`openmpf-projects/openmpf-contrib-components` directories. Next, add an entry to
`openmpf-projects/openmpf/trunk/jenkins/scripts/config_files/openmpf-open-source-package.json`
for your component.

Next, refer back to the steps listed in the [Build the OpenMPF Docker Images
](README.md#build-the-openmpf-docker-images) section in the README. If your
component requires a special SDK, tools, or other additions to the build
environment, then you will need to make modifications to the
`openmpf-docker/openmpf-build/Dockerfile` and run the command that starts with
`docker build openmpf_build` again to recreate the `openmpf_build` image. If
not, then don't run that command.

Execute the command that begins with `docker run` to build OpenMPF with your
code. Skip the step to run `docker-generate-compose-files.sh`. That should be
not be necessary unless you want to use a new registry or image tag. Then follow
the rest of the steps in that section to build the Docker images. Then run the
steps in the [Run OpenMPF using Docker
Compose](README.md#run-openmpf-using-docker-compose) section to deploy them.
Repeat these steps, starting with the `docker run` command, each time you make a
change to your component code and want to run it.

If you wish to use a different `openmpf-*-package.json` file that includes an
entry for your component, for example, `openmpf-with-my-component-package.json`,
then place that file in the same directory as
`openmpf-open-source-package.json`. Then, when executing the command that begins
with `docker run`, include the `-e
BUILD_PACKAGE_JSON=openmpf-with-my-component-package.json` option at the end of
the command. By convention, the name of your file should start with `openmpf-`
and end with `-package.json`.
