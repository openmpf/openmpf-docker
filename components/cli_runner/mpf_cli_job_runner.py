#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2023 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2023 The MITRE Corporation                                      #
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
import json
import logging
import mimetypes
import os
import shutil
import subprocess
import tempfile
from typing import Any, Callable, Dict, Iterable, List, Mapping, Optional, \
    TextIO, Union

import mpf_cli_runner_util as util

log = logging.getLogger('org.mitre.mpf.cli')


class JobRunner(contextlib.AbstractContextManager):
    def __init__(self,
                 cmd_line_args: argparse.Namespace,
                 env_props: Mapping[str, str],
                 job_stdin: TextIO,
                 component,
                 descriptor):
        with contextlib.ExitStack() as exit_stack:
            self._output_dest = cmd_line_args.output
            exit_stack.push(self._output_dest)

            self._component_handle = component
            self._sdk_module = component.sdk_module

            self._mime_type = self._get_mime_type(
                cmd_line_args.media_type, cmd_line_args.media_path, cmd_line_args.media_metadata)

            self._media_type = self._get_media_type(
                cmd_line_args.media_type, self._mime_type)

            if not self._component_handle.supports(self._media_type):
                raise RuntimeError(
                    f'The component does not support {self._media_type.name.lower()} jobs.')

            self._media_path = self._get_media_path(
                cmd_line_args.media_path, self._media_type, job_stdin, exit_stack)

            self._media_metadata = self._get_media_metadata(
                self._media_path, self._media_type, cmd_line_args.media_metadata)

            self._job_props = self._get_combined_job_props(
                cmd_line_args.job_props, env_props, descriptor)
            self._track_type = descriptor['algorithm']['trackType']

            self._begin = cmd_line_args.begin
            self._end = cmd_line_args.end
            self._pretty_print_results = cmd_line_args.pretty
            self._brief_output = cmd_line_args.brief
            self._exit_stack = exit_stack.pop_all()


    def __exit__(self, *exc_details):
        return self._exit_stack.__exit__(*exc_details)

    def run_job(self):
        job = self._create_job()
        start_time = datetime.datetime.now()
        component_results = self._component_handle.run_job(job)

        if self._media_type == util.MediaType.VIDEO:
            fps = float(self._media_metadata['FPS'])
        else:
            fps = 0

        result_dicts = ComponentResultToDictConverter.convert(
            fps, self._track_type, component_results)

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


    @classmethod
    def _get_combined_job_props(cls,
                                job_properties: Dict[str, str],
                                client_env_props: Mapping[str, str],
                                descriptor: Dict[str, Any]) -> Dict[str, str]:
        for pair in client_env_props.items():
            job_properties.setdefault(*pair)

        for pair in util.get_job_props_from_env(os.environ):
            job_properties.setdefault(*pair)

        descriptor_props_field = descriptor['algorithm']['providesCollection']['properties']
        for prop in descriptor_props_field:
            default_value = prop.get('defaultValue')
            if default_value is not None:
                job_properties.setdefault(prop['name'], default_value)

        return sort_property_dict(job_properties)


    def _wrap_component_results(
            self,
            result_dicts: List[Dict[str, Any]],
            start_time: datetime.datetime) -> Union[List[Dict[str, Any]], Dict[str, Any]]:
        if self._brief_output:
            return result_dicts

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
                        self._track_type: [
                            {
                                'tracks': result_dicts
                            }
                        ]
                    }
                }
            ]
        }

    @staticmethod
    def _get_media_path(media_path: str, media_type: util.MediaType, job_stdin: TextIO,
                        exit_stack: contextlib.ExitStack) -> str:
        if media_path != '-':
            if not os.path.exists(media_path):
                raise FileNotFoundError(
                    f'The provided media path, "{media_path}", does not exist.')
            return media_path

        client_std_in_path = f'/proc/{os.getpid()}/fd/{job_stdin.fileno()}'
        if media_type != util.MediaType.VIDEO or os.path.isfile(client_std_in_path):
            return client_std_in_path

        # if media_type != util.MediaType.VIDEO:
        #     return f'/proc/{os.getpid()}/fd/{job_request.stdin.fileno()}'

        tmp_file = exit_stack.enter_context(tempfile.NamedTemporaryFile())
        log.warning(f'Warning: Copying video to {tmp_file.name} '
                    'because videos can not be read directly from standard in.')
        shutil.copyfileobj(job_stdin.buffer, tmp_file)
        # Closing tmp_file causes the file to be deleted, so we can't close it here.
        # Since we can't close it, we need to flush here, otherwise the file will be partially
        # written.
        tmp_file.flush()
        return tmp_file.name



class ComponentResultToDictConverter:

    @classmethod
    def convert(cls, fps: float, track_type: str,
                component_results: Iterable) -> List[Dict[str, Any]]:
        """
        Convert component_results to JSON-serializable dictionaries
        :param fps: For video jobs, the video's frames per second. Otherwise, 0.
        :param track_type: Name of the track type produced by the component.
        :param component_results: Output from the component
        :return: A JSON-serializable representation of component_results
        """
        return cls(fps, track_type).to_dict_list(component_results)


    _convert_frame_to_time: Callable[[int], float]
    _track_type: str

    def __init__(self, fps: float, track_type: str):
        if fps == 0:
            self._convert_frame_to_time = lambda x: 0
        else:
            ms_per_frame = 1000 / fps
            self._convert_frame_to_time = lambda fr: round(fr * ms_per_frame)

        self._track_type = track_type

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
            type=self._track_type,
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
            track_dict['startOffsetTime'],
            track_dict['stopOffsetTime'],
            track_dict['type'],
            track_dict['confidence'],
            *track_dict['trackProperties'].items()
        ]


    @staticmethod
    def _detection_dict_compare_key(detection_dict: Dict[str, Any]) -> List:
        return [
            detection_dict['offsetFrame'],
            detection_dict['offsetTime'],
            detection_dict['confidence'],
            detection_dict['x'],
            detection_dict['y'],
            detection_dict['width'],
            detection_dict['height'],
            *detection_dict['detectionProperties'].items()
        ]


def sort_property_dict(unsorted: Dict[str, str]) -> Dict[str, str]:
    return {k: unsorted[k] for k in sorted(unsorted, key=lambda x: (x.upper(), x))}
