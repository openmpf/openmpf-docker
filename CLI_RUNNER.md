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
