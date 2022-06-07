## OpenMPF Command Line Runner ##
The OpenMPF Command Line Runner (CLI runner) allows users to run jobs with a single component
without the Workflow Manager. It only supports C++ and Python components. The CLI runner is built
in to the C++ and Python component base images, so the same Docker image is used whether you
want to run a regular component with Workflow Manager or use the CLI runner. 
The CLI runner does not support multi-component pipelines. It also does not segment media. 
It outputs results in a JSON structure that is a subset of the regular OpenMPF output. 


### Example Commands ###

This is the simplest possible command. It runs OCV face detection on `face.jpg`. 
`face.jpg` is a file on the host file system. It outputs the results to standard out.
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - < face.jpg
```

To store the results in a file on the host file system, you can redirect standard out to a file.
For example:
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - < face.jpg > out.json
```


All the examples that use `docker run`, can also be used with `docker exec`.
This is an example of running two jobs with the same container.
```shell script
docker run --rm -d --name ocv_face_runner openmpf_ocv_face_detection -d
docker exec -i ocv_face_runner runner -t image - < face.jpg
docker exec -i ocv_face_runner runner -t image - < other.jpg
docker stop ocv_face_runner
```

You can also mount a volume and run jobs with media in the volume. Note that
the paths are the path in the container file system.
```shell script
docker run --rm -v "$(pwd)":/mpfdata openmpf_ocv_face_detection /mpfdata/face.jpg
```


Job properties can be set using the `-P` flag. In the example below we set two
job properties. We set `MIN\_FACE\_SIZE` to 50 and `OTHER\_PROP` to 5.
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - -P MIN_FACE_SIZE=50 -P OTHER_PROP=5 < face.jpg
```

Media metadata can be set using the `-M` flag. In the example below we set the media metadata 
property `FPS` to 29.97.
```shell script
docker run --rm -i openmpf_ocv_face_detection -t video - -M FPS=29.97 < face.mp4
```

This is an example of using the runner in a shell pipeline. It allows us to preprocess the 
image without creating a temporary file. In this example we sharpen the image before passing
it to `openmpf_tesseract_ocr_text_detection`. The `convert` command is part of ImageMagick.
```shell script
convert -sharpen 20 eng.png bmp:- | docker run --rm -i openmpf_tesseract_ocr_text_detection -t image -
```


### Output Options ###
By default, the JSON output object is written to standard out. 
All logging goes to standard error to prevent it from interfering with the
JSON output.

Save JSON output to a file on host filesystem:
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - < face.jpg > out.json
```

Save JSON output to a file on host filesystem and print JSON to terminal:
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - < face.jpg | tee out.json
```

Save JSON output to a file on container filesystem:
```shell script
docker run --rm -i openmpf_ocv_face_detection -t image - -o out.json < face.jpg
```


### Command Line Arguments ###
For the full set of available command line arguments and documentation, run the component Docker
image with the `--help` argument.
```
$ docker run --rm openmpf_ocv_face_detection --help
usage: runner [-h] [--media-type {image,video,audio,generic}]
              [--job-prop <prop_name>=<value>]
              [--media-metadata <metadata_name>=<value>] [--begin BEGIN]
              [--end END] [--daemon] [--pretty] [--brief] [--output OUTPUT]
              [--descriptor DESCRIPTOR_FILE] [--verbose]
              media_path

positional arguments:
  media_path            Path to media to process. To read from standard in use
                        "-"

optional arguments:
  -h, --help            show this help message and exit
  --media-type {image,video,audio,generic}, -t {image,video,audio,generic}
                        Specify type of media. Required when reading media
                        from standard in. When not reading from standard in,
                        the file extension will be used to guess the media
                        type.
  --job-prop <prop_name>=<value>, -P <prop_name>=<value>
                        Set a job property for the job. The argument should be
                        the name of the job property and its value separated
                        by an "=" (e.g. "-P ROTATION=90"). This flag can be
                        specified multiple times to set multiple job
                        properties.
  --media-metadata <metadata_name>=<value>, -M <metadata_name>=<value>
                        Set a media metadata value. The argument should be the
                        name of the metadata field and its value separated by
                        an "=" (e.g. "-M FPS=29.97"). This flag can be
                        specified multiple times to set multiple metadata
                        fields.
  --begin BEGIN, -b BEGIN
                        For videos, the first frame number (0-based index) of
                        the video that should be processed. For audio, the
                        time (0-based index, in milliseconds) to begin
                        processing the audio file.
  --end END, -e END     For videos, the last frame number (0-based index) of
                        the video that should be processed. For audio, the
                        time (0-based index, in milliseconds) to stop
                        processing the audio file.
  --daemon, -d          Start up and sleep forever. This can be used to keep
                        the Docker container alive so that jobs can be started
                        with `docker exec <container-id> runner ...` .
  --pretty, -p          Pretty print JSON output.
  --brief               Only output tracks.
  --output OUTPUT, -o OUTPUT
                        The path where the JSON output should written. When
                        omitted, JSON output is written to standard out.
  --descriptor DESCRIPTOR_FILE
                        Specifies which descriptor to use when multiple
                        descriptors are present. Usually only needed when
                        running outside of docker.
  --verbose, -v         When provided once, set the log level to DEBUG. When
                        provided twice (e.g. "-vv"), set the log level to
                        TRACE
```

### Idle Timeout ###
The `COMPONENT_SERVER_IDLE_TIMEOUT` environment variable can be used to configure the idle timeout
of the ComponentServer and ExecutorProcesses. The ComponentServer maintains a worker pool
of ExecutorProcesses to process jobs. See 
[Appendix: Technical Information](#appendix-technical-information) for details.

The environment variable does not apply when the ComponentServer is directly started when using
`docker run` with the `-d` or `--daemon` command line argument. It only applies if the 
ComponentServer is started automatically when using `docker exec` on a container not already 
running the ComponentServer. When the ComponentServer times out, the next use of `docker exec` will 
create a new one.

The environment variable always applies to ExecutorProcesses. It's helpful for each of these 
processes to persist in the worker pool for a period of time to avoid reinitializing them, which 
may involve loading large models into memory. When a ExecutorProcess times out, it will be removed 
from the worker pool. The next use of `docker exec` will create a new one, if necessary.

The environment variable should be set when the Docker container is started. When not provided,
it defaults to 60 seconds.

When applied to an ExecutorProcess:
- Positive: Number of seconds to wait for a new job before exiting.
- 0: Exit after processing a single job.
- Negative: Wait for a new job forever.

When applied to ComponentServer:
- Positive: After all ExecutorProcesses have exited, number of seconds to wait for a new job 
  before exiting.
- 0: Exit as soon as the last ExecutorProcess exits. Jobs received while waiting for the 
  ExecutorProcesses to exit will still be processed.
- Negative: Wait for a new job forever.


### Known Issues ###

#### Starting a Lot of Simultaneous Job ####
When submitting more than 350 jobs at the same time, the Docker binary fails with an error like:
```
runtime/cgo: pthread_create failed: Resource temporarily unavailable
SIGABRT: abort
PC=0x7f889ff8c387 m=3 sigcode=18446744073709551610

goroutine 0 [idle]:
runtime: unknown pc 0x7f889ff8c387
stack: frame={sp:0x7f8878c42918, fp:0x0} stack=[0x7f88784432a8,0x7f8878c42ea8)
00007f8878c42818:  736e692f6b6e7572  62696c2f6c6c6174 
00007f8878c42828:  736e617274442d20  6175672e74726f70 
00007f8878c42838:  273d6565746e6172  442d2027454e4f4e 
00007f8878c42848:  747365722e626577  6f636f746f72702e 
00007f8878c42858:  2770747468273d6c  0000000000000000 
00007f8878c42868:  0000000000000000  0000000000000000 
00007f8878c42878:  0000000000000000  2e656d69746e7572 
...

goroutine 7 [chan receive]:
github.com/docker/cli/vendor/k8s.io/klog.(*loggingT).flushDaemon(0x55ace53bc360)
    /go/src/github.com/docker/cli/vendor/k8s.io/klog/klog.go:1010 +0x8d
created by github.com/docker/cli/vendor/k8s.io/klog.init.0
    /go/src/github.com/docker/cli/vendor/k8s.io/klog/klog.go:411 +0xd8

rax    0x0
rbx    0x7f88a031e868
rcx    0xffffffffffffffff
rdx    0x6
rdi    0x100b1
rsi    0x100bb
rbp    0x55ace3fd2e04
rsp    0x7f8878c42918
....
```
This is an issue with the Docker binary. It occurs before any OpenMPF code runs.


#### docker exec doesn't forward ctrl-c without -t  ####
If you start a job by running `docker exec` and don't include the `-t` or the `--tty` option,
ctrl-c causes `docker exec` to exit, but the program started by `docker exec` will still be
running in the container.



### Appendix: Technical Information ###
The CLI runner behaves like a typical command line program, but the jobs are actually executed by
a server process. Some components load large model files. When running short jobs, loading the
model can take longer than the job itself. A server process is used so that a single component
instance can be re-used across multiple runs. When a job is received, it is either assigned
to an idle ExecutorProcess or a new ExecutorProcess is created. There is no queueing and no limit
to the number of ExecutorProcesses that may be created. A user can limit the number of
ExecutorProcesses by waiting for existing jobs to complete before submitting more.


### Parts ###
1. Client - The program that the user starts. It connects to the socket that ComponentServer is
   listening on to submit a job.
2. ComponentServer - Listens on a Unix socket for new jobs and forwards the job request to an
   ExecutorProcess. If there are no idle processes when a job is received, a new ExecutorProcess
   is created.
3. ExecutorProcess - Child process of ComponentServer that actually runs the jobs.


#### Protocol ####
1. Either:
    - The ComponentServer was started manually by using the `-d` or `--daemon` command line 
      argument. ComponentServer will never exit due to idle, but ExecutorProcesses will unless 
      disabled.
    - The client was started while server not running. Client will start a new process to run
      ComponentServer before running the job. In this case both ComponentServer and
      ExecutorProcesses will use the `COMPONENT_SERVER_IDLE_TIMEOUT` environment variable to
      determine idle timeout behavior.
2. ComponentServer listens to a Unix socket with address `b'\x00mpf_cli_runner.sock'`.
3. Client connects to Unix socket with address `b'\x00mpf_cli_runner.sock'`.
4. ComponentServer accepts the connection and creates the `client_sock` socket.
5. ComponentServer looks for an idle ExecutorProcess. If there are no idle ExecutorProcesses a new
   one will be created. During the creation of an ExecutorProcess a pair of unnamed Unix sockets
   are created using `socketpair`. They are used for communication between ComponentServer and
   ExecutorProcess.
6. ComponentServer sends `client_sock` to ExecutorProcess using the unnamed socket pair. All further
   interaction with `client_sock` is handled by the ExecutorProcess.
7. The ExecutorProcess begins reading from `client_sock` to receive the job request.
8. Using the Unix socket connected to `b'\x00mpf_cli_runner.sock'`, the client sends the following
   messages:
    - 1 byte of regular data and ancillary data containing the file descriptors for the client's
      standard in, standard out, and standard error in that order. When sending ancillary data
      at least one byte of regular data must be sent. The byte of regular data is ignored.
    - The client's command line arguments as a list of strings encoded using pickle.
    - The client's current working directory as a string encoded using pickle.
    - The client's environment variables that started with `MPF_PROP_` as dictionary with string
      keys and values encoded using pickle.
9. ExecutorProcess executes the job.
10. ExecutorProcess writes JSON output to configured location.
11. ExecutorProcess sends a byte to `client_sock`. The byte is the exit code that the client should
    exit with. It is unsigned because Linux exit codes are required to be in the range 0-255.
12. ExecutorProcess sends one byte to ComponentServer to inform ComponentServer that it is done
    running the job and is now idle.
13. ExecutorProcess waits for a new job from ComponentServer. If it does not receive a job before
    the configured timeout, it will exit.
