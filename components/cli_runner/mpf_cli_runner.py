#!/usr/bin/env python3

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2021 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2021 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

import argparse
import contextlib
import datetime
import enum
import glob
import json
import logging
import mimetypes
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
from typing import Dict, Any, TextIO, Optional, List, Callable, Union, Iterable

import mpf_cli_runner_util as util


log = logging.getLogger('org.mitre.mpf.cli')

def main():
    try:
        true_std_out = redirect_std_out()
        fix_sig_term()
        args = parse_cmd_line_args(true_std_out)
        configure_logging(args)
        if args.daemon:
            run_as_daemon()
            return
        with JobRunner(args) as runner:
            runner.run_job()

    except Exception as e:
        if log.isEnabledFor(logging.DEBUG):
            log.exception(f'Job failed due to: {e}')
        else:
            log.error(f'Job failed due to: {e}')
        sys.exit(1)


class JobRunner:
    _exit_stack: contextlib.ExitStack
    _output_dest: TextIO
    _component_handle: util.ComponentHandle
    _sdk_module: Any
    _media_type: util.MediaType
    _media_path: str
    _media_metadata: Dict[str, str]
    _job_props: Dict[str, str]
    _begin: int
    _end: int
    _pretty_print_results: bool
    _brief_output: bool


    def __init__(self, cmd_line_args):
        self._exit_stack = contextlib.ExitStack()
        self._output_dest = cmd_line_args.output
        self._exit_stack.push(self._output_dest)

        descriptor = self._load_descriptor(cmd_line_args.descriptor_file)

        lang = descriptor['sourceLanguage'].lower()
        if lang == 'c++':
            # Need to conditionally import because the C++ SDK won't be installed in Python
            # component images.
            import mpf_cpp_runner
            self._component_handle = self._exit_stack.enter_context(
                    mpf_cpp_runner.CppComponentHandle(descriptor))
        elif lang == 'python':
            # Need to conditionally import because the Python SDK won't be installed in C++
            # component images.
            import mpf_python_runner
            self._component_handle = mpf_python_runner.PythonComponentHandle(descriptor)
        else:
            raise NotImplementedError(f'{lang} components are not supported.')

        self._sdk_module = self._component_handle.sdk_module


        self._mime_type = self._get_mime_type(
            cmd_line_args.media_type, cmd_line_args.media_path, cmd_line_args.media_metadata)

        self._media_type = self._get_media_type(cmd_line_args.media_type, self._mime_type)

        if not self._component_handle.supports(self._media_type):
            raise RuntimeError(
                f'The component does not support {self._media_type.name.lower()} jobs.')

        self._media_path = self._get_media_path(cmd_line_args.media_path, self._media_type,
                                                self._exit_stack)
        self._media_metadata = self._get_media_metadata(
                    self._media_path, self._media_type, cmd_line_args.media_metadata)

        self._job_props = self._get_combined_job_props(cmd_line_args.job_props, descriptor)

        self._begin = cmd_line_args.begin
        self._end = cmd_line_args.end
        self._pretty_print_results = cmd_line_args.pretty
        self._brief_output = cmd_line_args.brief


    def __enter__(self):
        return self

    def __exit__(self, *exc_details):
        return self._exit_stack.__exit__(*exc_details)


    def run_job(self) -> None:
        job = self._create_job()
        start_time = datetime.datetime.now()
        component_results = self._component_handle.run_job(job)

        if self._media_type == util.MediaType.VIDEO:
            fps = float(self._media_metadata['FPS'])
        else:
            fps = 0

        result_dicts = ComponentResultToDictConverter.convert(
            fps, self._component_handle.detection_type, component_results)

        if self._media_type == util.MediaType.IMAGE:
            log.info(f'Found {len(result_dicts)} detections.\n')
        elif self._media_type == util.MediaType.VIDEO:
            num_detections = sum(len(t['detections']) for t in result_dicts)
            log.info(f'Found {len(result_dicts)} tracks containing a total of '
                     f'{num_detections} detections.\n')
        else:
            log.info(f'Found {len(result_dicts)} tracks.\n')

        wrapped_results = self._wrap_component_results(result_dicts, start_time)
        indent = 4 if self._pretty_print_results else None
        json.dump(wrapped_results, self._output_dest, ensure_ascii=False, indent=indent)


    def _create_job(self) -> Any:
        job_name = os.path.basename(self._media_path)
        media_type = self._media_type

        if media_type == util.MediaType.IMAGE:
            return self._sdk_module.ImageJob(job_name, self._media_path, self._job_props,
                                             self._media_metadata)

        if media_type == util.MediaType.VIDEO:
            return self._sdk_module.VideoJob(job_name, self._media_path, self._begin, self._end,
                                             self._job_props, self._media_metadata)

        if media_type == util.MediaType.AUDIO:
            return self._sdk_module.AudioJob(job_name, self._media_path, self._begin, self._end,
                                             self._job_props, self._media_metadata)

        if media_type == util.MediaType.GENERIC:
            return self._sdk_module.GenericJob(job_name, self._media_path, self._job_props,
                                               self._media_metadata)

        raise RuntimeError(f'Unknown media type: {media_type}')


    def _wrap_component_results(
            self,
            result_dicts: List[Dict[str, Any]],
            start_time: datetime.datetime) -> Union[List[Dict[str, Any]], Dict[str, Any]]:
        if self._brief_output:
            return result_dicts
        detection_type = self._component_handle.detection_type

        # Create a structure that will be parsable by the mpf-interop package. Some fields
        # don't exactly make sense, but are necessary for compatibility. For example, the media
        # field is a list even though the CLI runner only operates on a single piece of media.
        return {
            'timeStart': start_time.astimezone().isoformat(),
            'timeStop': datetime.datetime.now().astimezone().isoformat(),
            'jobProperties': self._job_props,
            'media': [
                {
                    'path': self._media_path,
                    'mimeType': self._mime_type,
                    'mediaMetadata': self._media_metadata,
                    'output': {
                        detection_type: [
                            {
                                'tracks': result_dicts
                            }
                        ]
                    }
                }
            ]
        }


    @classmethod
    def _load_descriptor(cls, descriptor_file: Optional[TextIO]) -> Dict[str, Any]:
        if descriptor_file:
            log.info(f'Loading descriptor from {descriptor_file.name}')
            descriptor = json.load(descriptor_file)
            descriptor_file.close()
            cls._set_env_vars_from_descriptor(descriptor)
            return descriptor

        mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
        glob_pattern = os.path.join(mpf_home, 'plugins/*/descriptor/descriptor.json')
        glob_matches = glob.glob(glob_pattern)

        if len(glob_matches) == 1:
            descriptor_path = glob_matches[0]
            log.info(f'Loading descriptor from {descriptor_path}')
            with open(descriptor_path) as f:
                descriptor = json.load(f)
            cls._set_env_vars_from_descriptor(descriptor)
            return descriptor

        if len(glob_matches) == 0:
            raise RuntimeError(f'Expecting to find a descriptor file at "{glob_pattern}", '
                               'but it was not there.')
        else:
            raise RuntimeError(f'Expected to find one descriptor matching "{glob_pattern}", '
                               f'but the following descriptors were found: {glob_matches}')

    @staticmethod
    def _set_env_vars_from_descriptor(descriptor: Dict[str, Any]) -> None:
        env = os.environ
        for json_env_var in descriptor.get('environmentVariables', ()):
            var_name = json_env_var['name']
            var_value = util.expand_env_vars(json_env_var['value'], env)
            sep = json_env_var.get('sep')

            existing_val = env.get(var_name) if sep else None
            if sep and existing_val:
                env[var_name] = existing_val + sep + var_value
            else:
                env[var_name] = var_value

    @staticmethod
    def _get_media_path(media_path: str, media_type: util.MediaType,
                        exit_stack: contextlib.ExitStack) -> str:
        if media_path != '-':
            if not os.path.exists(media_path):
                raise FileNotFoundError(
                    f'The provided media path, "{media_path}", does not exist.')
            return media_path

        if media_type != util.MediaType.VIDEO or os.path.isfile('/dev/stdin'):
            return '/dev/stdin'

        tmp_file = exit_stack.enter_context(tempfile.NamedTemporaryFile())
        log.warning(f'Warning: Copying video to {tmp_file.name} '
                    'because videos can not be read directly from standard in.')
        shutil.copyfileobj(sys.stdin.buffer, tmp_file)
        # Closing tmp_file causes the file to be deleted, so we can't close it here.
        # Since we can't close it, we need to flush here, otherwise the file will be partially
        # written.
        tmp_file.flush()
        return tmp_file.name


    @classmethod
    def _get_media_metadata(cls, media_path: str, media_type: util.MediaType,
                            media_metadata: Dict[str, str]) -> Dict[str, str]:
        if media_type == util.MediaType.VIDEO and 'FPS' not in media_metadata:
            log.info('FPS was not provided in the media metadata. Checking FPS with ffprobe...')
            fps = cls._get_fps(media_path)
            log.info(f'Determined FPS to be {fps}.')
            media_metadata['FPS'] = str(fps)

        return sort_property_dict(media_metadata)


    @staticmethod
    def _get_fps(media_path: str) -> float:
        try:
            # Output is like 2997/100 or 1/1
            completed_proc = subprocess.run(
                ('ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                 'stream=avg_frame_rate', '-of', 'default=noprint_wrappers=1:nokey=1', media_path),
                capture_output=True, text=True, check=True)

            numerator, denominator = completed_proc.stdout.split('/')
            return float(numerator) / float(denominator)

        except subprocess.CalledProcessError as e:
            raise RuntimeError(f'Unable to determine FPS with ffprobe. Please set it on the '
                               f'command line using "-M FPS=x". ffprobe stderr: {e.stderr}') from e


    @staticmethod
    def _get_combined_job_props(job_properties: Dict[str, str],
                                descriptor: Dict[str, Any]) -> Dict[str, str]:
        property_prefix = 'MPF_PROP_'
        for var_name, var_value in os.environ.items():
            if len(var_name) > len(property_prefix) and var_name.startswith(property_prefix):
                prop_name = var_name[len(property_prefix):]
                job_properties.setdefault(prop_name, var_value)

        descriptor_props_field = descriptor['algorithm']['providesCollection']['properties']
        for prop in descriptor_props_field:
            default_value = prop.get('defaultValue')
            if default_value is not None:
                job_properties.setdefault(prop['name'], default_value)

        return sort_property_dict(job_properties)


    @staticmethod
    def _get_mime_type(provided_media_type: Optional[util.MediaType],
                       media_path: str,
                       media_metadata: Dict[str, str]) -> str:

        mime_type = media_metadata.get('MIME_TYPE')
        if not mime_type:
            # Known to be missing mime types
            mimetypes.add_type('video/x-matroska', '.mkv')
            mimetypes.add_type('video/ogg', '.ogg')
            mime_type = mimetypes.guess_type(media_path, strict=False)[0]

        if mime_type:
            media_metadata['MIME_TYPE'] = mime_type
            return mime_type

        if provided_media_type:
            mime_type = provided_media_type.name.lower() + '/octet-stream'
            log.warning(
                f'Unable to determine mime type. Using the bogus mime type: {mime_type}. '
                'To set it correctly add "-M MIME_TYPE=<actual mime type>" on the command line.')
            return mime_type
        else:
            raise RuntimeError('Unable to determine file type. It must be explicitly provided '
                               'with the --media-type/-t argument.')

    @staticmethod
    def _get_media_type(given_media_type: Optional[util.MediaType],
                        mime_type: str) -> util.MediaType:
        if given_media_type:
            return given_media_type

        log.warning('Media type argument missing. Attempting to guess file type...')
        mime_type = mime_type.lower()
        if 'video' in mime_type:
            log.warning(f'Guessed that this is a video job because the mime type was {mime_type}.')
            return util.MediaType.VIDEO

        if 'image' in mime_type:
            log.warning(f'Guessed that this is an image job because the mime type was {mime_type}.')
            return util.MediaType.IMAGE

        if 'audio' in mime_type:
            log.warning(f'Guessed that this is an audio job because the mime type was {mime_type}.')
            return util.MediaType.AUDIO

        if 'text' in mime_type or 'pdf' in mime_type:
            log.warning(
                f'Guessed that this is a generic job because the mime type was {mime_type}.')
            return util.MediaType.GENERIC

        raise RuntimeError(f'Unable to determine job type from mime type ({mime_type}). '
                           'It must be explicitly provided with the --media-type/-t argument.')



class ComponentResultToDictConverter:
    @classmethod
    def convert(cls, fps: float, detection_type: str,
                component_results: Iterable) -> List[Dict[str, Any]]:
        """
        Convert component_results to JSON-serializable dictionaries
        :param fps: For video jobs, the video's frames per second. Otherwise, 0.
        :param detection_type: Name of the detection type produced by the component.
        :param component_results: Output from the component
        :return: A JSON-serializable representation of component_results
        """
        return cls(fps, detection_type).to_dict_list(component_results)


    _convert_frame_to_time: Callable[[int], float]
    _detection_type: str

    def __init__(self, fps: float, detection_type: str):
        if fps == 0:
            self._convert_frame_to_time = lambda x: 0
        else:
            ms_per_frame = 1000 / fps
            self._convert_frame_to_time = lambda fr: round(fr * ms_per_frame)

        self._detection_type = detection_type

    def to_dict_list(self, component_results: Iterable) -> List[Dict[str, Any]]:
        result_dicts = [self._create_track_dict(obj) for obj in component_results]
        result_dicts.sort(key=self._track_dict_compare_key)
        return result_dicts


    def _create_track_dict(self, obj) -> Dict[str, Any]:
        frame_locations = getattr(obj, 'frame_locations', None)
        if frame_locations is None:
            frame_locations = {0: obj}

        serialized_detections = [self._create_detection_dict(frame_locations[i], i)
                                 for i in frame_locations]
        serialized_detections.sort(key=self._detection_dict_compare_key)

        serialized_exemplar = max(serialized_detections, key=lambda x: x['confidence'],
                                  default=None)

        start_frame = getattr(obj, 'start_frame', 0)
        stop_frame = getattr(obj, 'stop_frame', 0)

        start_time = getattr(obj, 'start_time', self._convert_frame_to_time(start_frame))
        stop_time = getattr(obj, 'stop_time', self._convert_frame_to_time(stop_frame))

        return dict(
            startOffsetFrame=start_frame,
            stopOffsetFrame=stop_frame,
            startOffsetTime=start_time,
            stopOffsetTime=stop_time,
            type=self._detection_type,
            confidence=obj.confidence,
            trackProperties=sort_property_dict(obj.detection_properties),
            exemplar=serialized_exemplar,
            detections=serialized_detections
        )


    def _create_detection_dict(self, detection, frame_number: int) -> Dict[str, Any]:
        start_time = getattr(detection, 'start_time', self._convert_frame_to_time(frame_number))
        return dict(offsetFrame=frame_number,
                    offsetTime=start_time,
                    x=getattr(detection, 'x_left_upper', 0),
                    y=getattr(detection, 'y_left_upper', 0),
                    width=getattr(detection, 'width', 0),
                    height=getattr(detection, 'height', 0),
                    confidence=detection.confidence,
                    detectionProperties=sort_property_dict(detection.detection_properties))


    @staticmethod
    def _track_dict_compare_key(track_dict: Dict[str, Any]) -> List:
        return [
            track_dict['startOffsetFrame'],
            track_dict['stopOffsetFrame'],
            track_dict['type'],
            track_dict['confidence'],
            *track_dict['trackProperties'].items()
        ]


    @staticmethod
    def _detection_dict_compare_key(detection_dict: Dict[str, Any]) -> List:
        return [
            detection_dict['offsetFrame'],
            detection_dict['confidence'],
            detection_dict['x'],
            detection_dict['y'],
            detection_dict['width'],
            detection_dict['height'],
            *detection_dict['detectionProperties'].items()
        ]


def run_as_daemon() -> None:
    try:
        signal.pause()
    except KeyboardInterrupt:
        sys.exit(128 + signal.SIGINT)


def fix_sig_term() -> None:
    """
    Explicitly handle SIGTERM when running as pid 1.
    This is required because Linux disables the default signal handlers for pid 1.
    """
    if os.getpid() == 1:
        # Linux disables default signal handlers for pid 1.
        signal.signal(signal.SIGTERM, lambda sig_num, frame: sys.exit(128 + sig_num))


def dump_useful_keys(job_results):
    keys = ('TEXT', 'TRANSCRIPT', 'CLASSIFICATION')
    for key in keys:
        any_match = any(key in r.detection_properties for r in job_results)
        if not any_match:
            continue
        print(f'============ {key} ===============')
        for result in job_results:
            print(result.detection_properties.get(key))
            print(f'============ {key} ===============')


def redirect_std_out() -> TextIO:
    """
    Make code trying to write to standard out write to standard error instead.
    This is to ensure that only the JSON output object gets written to standard out.
    :return: A file object that can be used to write to the process's true standard out.
    """
    if mpf_exec_std_out := os.environ.get('MPF_EXEC_STD_OUT'):
        std_out_fd_copy = int(mpf_exec_std_out)
    else:
        std_out_fd = 1
        std_err_fd = 2
        # Copy standard out to a brand new file descriptor that the component library doesn't
        # know about.
        std_out_fd_copy = os.dup(std_out_fd)
        # Copy standard error to file descriptor 1.
        os.dup2(std_err_fd, std_out_fd)

    sys.stdout.flush()
    sys.stderr.flush()
    # Even though sys.stdout and sys.stderr are now writing the same file descriptor,
    # they are still separate file objects with their own internal buffers.
    # We assign sys.stdout = sys.stderr so that they both refer to the same file object.
    sys.stdout = sys.stderr

    std_out_copy = os.fdopen(std_out_fd_copy, 'w')
    os.set_inheritable(std_out_fd_copy, True)
    return std_out_copy


def sort_property_dict(unsorted: Dict[str, str]) -> Dict[str, str]:
    return {k: unsorted[k] for k in sorted(unsorted, key=lambda x: (x.upper(), x))}


def configure_logging(cmd_line_args) -> None:
    if cmd_line_args.verbose == 1:
        log_level = 'DEBUG'
    elif cmd_line_args.verbose >= 2:
        log_level = 'TRACE'
    elif log_level := os.environ.get('LOG_LEVEL'):
        log_level = log_level.upper()
        if log_level == 'WARNING':
            # Python logging accepts either WARNING or WARN, but Log4CXX requires it be WARN.
            log_level = 'WARN'
        elif log_level == 'CRITICAL':
            # Python logging accepts either CRITICAL or FATAL, but Log4CXX requires it be FATAL.
            log_level = 'FATAL'
        elif log_level not in ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'):
            print(f'Invalid log level of "{log_level}" provided. Log level will be set to DEBUG.')
            log_level = 'DEBUG'
    else:
        log_level = 'INFO'

    # Log4cxxConfig.xml checks the $LOG_LEVEL environment variable
    os.environ['LOG_LEVEL'] = log_level

    if log_level == 'TRACE':
        # Python doesn't use TRACE so we just log everything when TRACE is provided.
        log_level = 'NOTSET'
    log_format = '%(levelname)-5s [%(filename)s:%(lineno)d] - %(message)s'
    logging.basicConfig(format=log_format, level=log_level)


def parse_cmd_line_args(true_std_out: TextIO) -> argparse.Namespace:
    if len(sys.argv) == 2 and (sys.argv[1] == '-d' or sys.argv[1] == '--daemon'):
        return argparse.Namespace(daemon=True)

    class ParseEnumAction(argparse.Action):
        def __init__(self, enum: enum.EnumMeta, **kwargs):
            kwargs['choices'] = [e.name.lower() for e in enum]
            super().__init__(**kwargs)
            self._enum = enum

        def __call__(self, parser, namespace, value, option_string=None):
            enum_element = self._enum[value.upper()]
            setattr(namespace, self.dest, enum_element)

    class ParsePropsAction(argparse.Action):
        def __init__(self, **kwargs):
            if 'default' not in kwargs:
                kwargs['default'] = {}
            super().__init__(**kwargs)

        def __call__(self, parser, namespace, value, option_string=None):
            existing_props = getattr(namespace, self.dest)
            prop_key, prop_val = value.split('=', 1)
            existing_props[prop_key] = prop_val

    parser = argparse.ArgumentParser()
    parser.add_argument('media_path',
                        help='Path to media to process. To read from standard in use "-"')
    parser.add_argument(
        '--media-type', '-t', enum=util.MediaType, action=ParseEnumAction,
        help='Specify type of media. Required when reading media from standard in. When not '
             'reading from standard in, the file extension will be used to guess the media type.')

    parser.add_argument(
        '--job-prop', '-P', action=ParsePropsAction, dest='job_props',
        metavar='<prop_name>=<value>',
        help='Set a job property for the job. The argument should be the name of the job property '
             'and its value separated by an "=" (e.g. "-P ROTATION=90"). '
             'This flag can be specified multiple times to set multiple job properties.')

    parser.add_argument(
        '--media-metadata', '-M', action=ParsePropsAction, metavar='<metadata_name>=<value>',
        help='Set a media metadata value. The argument should be the name of the metadata field '
             'and its value separated by an "=" (e.g. "-M FPS=29.97"). '
             'This flag can be specified multiple times to set multiple metadata fields.')

    parser.add_argument(
        '--begin', '-b', type=int, default=0,
        help='For videos, the first frame number (0-based index) of the video that should be '
             'processed. For audio, the time (0-based index, in milliseconds) to begin processing '
             'the audio file.'
    )
    parser.add_argument(
        '--end', '-e', type=int, default=-1,
        help='For videos, the last frame number (0-based index) of the video that should be '
             'processed. For audio, the time (0-based index, in milliseconds) to stop processing '
             'the audio file.')

    parser.add_argument(
        '--daemon', '-d', action='store_true',
        help='Start up and sleep forever. This can be used to keep the Docker container alive so '
             'that jobs can be started with `docker exec <container-id> runner ...` .')

    parser.add_argument('--pretty', '-p', action='store_true', help='Pretty print JSON output.')

    parser.add_argument('--brief', action='store_true', help='Only output tracks.')

    parser.add_argument(
        '--output', '-o', type=argparse.FileType('w'), default=true_std_out,
        help='The path where the JSON output should written. '
             'When omitted, JSON output is written to standard out.')

    parser.add_argument(
        '--descriptor', type=argparse.FileType('r'), dest='descriptor_file',
        help='Specifies which descriptor to use when multiple descriptors are present. '
             'Usually only needed when running outside of docker.')

    parser.add_argument(
        '--verbose', '-v', action='count', default=0,
        help='When provided once, set the log level to DEBUG. '
             'When provided twice (e.g. "-vv"), set the log level to TRACE')

    args = parser.parse_args()
    if args.media_type is None and args.media_path == '-':
        parser.error('When reading from standard in --media-type/-t must be provided.')
    return args


if __name__ == '__main__':
    main()
