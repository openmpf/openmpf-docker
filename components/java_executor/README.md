Overview
==================
The purpose of this image is to enable a developer to write a Java component for OpenMPF that can be encapsulated
within a Docker container. This isolates the execution environment from the rest of OpenMPF,
thereby providing greater freedom and portability. The `openmpf_java_component_build` and `openmpf_java_executor` 
base images are designed to work together in a multi-stage Docker build.

This image will:

- Register your component with the Workflow Manager.
- Execute your code using the OpenMPF component executor binary.
- Tail log files so that they appear in the terminal window where you ran `docker run ..`
  to start your component container.
  
  
How to build the `openmpf_java_component_build` and `openmpf_java_executor` base images
======================================================
```bash
cd /path/to/openmpf-docker/components
DOCKER_BUILDKIT=1 docker build . -f java_component_build/Dockerfile -t openmpf_java_component_build
DOCKER_BUILDKIT=1 docker build . -f java_executor/Dockerfile -t openmpf_java_executor
```


How to use this image
===========================
The following steps assume you are using the default project structure for OpenMPF Java components. Documentation
for Java components can be found [here](https://openmpf.github.io/docs/site/Java-Batch-Component-API). 

The [SphinxSpeechDetection component](https://github.com/openmpf/openmpf-components/tree/master/java/SphinxSpeechDetection) 
is a good example of a Dockerized Java component.

### Create a Dockerfile in your Java component project
You should put your Dockerfile in the component project's top level directory. For example:

```
MyFaceDetection
├── Dockerfile
├── assemblyDescriptor.xml
├── plugin-files
│   └── descriptor
│       └── descriptor.json
├── pom.xml
└── src
    └── main
        ├── java
        │   └── com
        │       └── example
        │           └── face
        │               └── detection
        │                   └── MyFaceDetection.java
        └── resources
            ├── applicationContext.xml
            └── log4j2.xml
```

The minimal Dockerfile is:
```dockerfile
# In first stage of the build we extend the openmpf_java_component_build base image.
FROM openmpf_java_component_build:latest as build_component

# If your component has external dependencies, you would add the commands necessary to download 
# or build the dependencies here. Adding the dependencies prior the copying in your source code 
# allows you to take advantage of the Docker build cache to avoid re-installing the dependencies 
# every time your source code changes.
# e.g. RUN yum install -y mydependency


# Start by just copying your pom.xml file.
COPY pom.xml pom.xml

# Download Maven dependencies before copying in the rest of the source code so that 
# Maven doesn't need to re-download dependencies every time the source code changes.
RUN mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.1:go-offline;

# Copy in the rest of your source code.
COPY . .

# Build and package your component.
RUN mvn package -Dmpf.assembly.format=dir 



# In the second stage of the build we extend the openmpf_java_executor base image. 
FROM openmpf_java_executor:latest

# If your component has runtime dependencies other than the Maven libraries required at 
# compile time you should install them here. Adding the dependencies prior to copying your 
# component's build artifacts allows you to take advantage of the Docker build cache to avoid 
# re-installing the dependencies every time your source code changes.


# Copy only the files the component will need at runtime from the build stage. 
# This line also copies over the jar dependencies. 
# One of the things that the `mvn package` command does is collect the jar dependencies.
COPY --from=build_component \
    /home/mpf/component_src/target/plugin-packages/MyFaceDetection/MyFaceDetection \
    $PLUGINS_DIR/MyFaceDetection
```

Your Dockerfile may use more than the two stages shown above, but the final stage in the Dockerfile must be the
`FROM openmpf_java_executor:latest` stage.


### Build your component image
Run the following command, replacing `<component_name>` with the name of your component and `<component_path>` with the
path on the host file system to the component projects's top level directory:
```bash
docker build -t <component_name> <component_path>
```


### Run your component
1. Start OpenMPF
2. Run the following command replacing `<component_name>` with the value provided in the build step. 
   If your OpenMPF deployment uses non-default credentials the `WFM_USER` and `WFM_PASSWORD` values will need to be 
   modified.
```bash
docker run \
    --network openmpf_default \
    -v openmpf_shared_data:/opt/mpf/share \
    -e WFM_USER=admin \
    -e WFM_PASSWORD=mpfadm \
    <component_name>
```
