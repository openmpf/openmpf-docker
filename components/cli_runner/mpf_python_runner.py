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

import pkg_resources
from typing import Any, Mapping, Union, Iterable

import mpf_cli_runner_util as util
import mpf_component_api
from mpf_component_api import ImageLocation, VideoTrack, AudioTrack, GenericTrack



class PythonComponentHandle(util.ComponentHandle):
    sdk_module = mpf_component_api

    def __init__(self, descriptor: Mapping[str, Any]):
        component_cls = self._load_component(descriptor)
        self._component = component_cls()
        self.track_type = descriptor['algorithm']['trackType']


    @classmethod
    def _load_component(cls, descriptor) -> type:
        distribution_name = descriptor['batchLibrary']
        entry_points = pkg_resources.get_entry_map(distribution_name, 'mpf.exported_component')

        if not entry_points:
            raise RuntimeError(f'The "{distribution_name}" component did not declare a '
                               '"mpf.exported_component" entrypoint')

        # The left hand side of the '=' in entry point declaration should be "component".
        # For example: 'mpf.exported_component': 'component = my_module:MyComponentClass'
        component_entry_point = entry_points.get('component')
        if component_entry_point is None:
            # An entry point in the "mpf.exported_component" group was found,
            # but the left hand side of the '=' was something else.
            # For example: 'mpf.exported_component': 'MyComponentClass = my_module:MyComponentClass'
            # We really only care about the entry point group, since we don't do anything with
            # entry point name.
            component_entry_point = next(iter(entry_points.values()))
        return component_entry_point.load()


    def supports(self, media_type: util.MediaType) -> bool:
        if media_type == util.MediaType.IMAGE:
            return hasattr(self._component, 'get_detections_from_image')
        if media_type == util.MediaType.VIDEO:
            return hasattr(self._component, 'get_detections_from_video')
        if media_type == util.MediaType.AUDIO:
            return hasattr(self._component, 'get_detections_from_audio')
        if media_type == util.MediaType.GENERIC:
            return hasattr(self._component, 'get_detections_from_generic')
        return False


    def run_job(self, job) -> Union[Iterable[ImageLocation], Iterable[VideoTrack],
                                    Iterable[AudioTrack], Iterable[GenericTrack]]:
        if isinstance(job, mpf_component_api.ImageJob):
            return self._component.get_detections_from_image(job)

        if isinstance(job, mpf_component_api.VideoJob):
            return self._component.get_detections_from_video(job)

        if isinstance(job, mpf_component_api.AudioJob):
            return self._component.get_detections_from_audio(job)

        if isinstance(job, mpf_component_api.GenericJob):
            return self._component.get_detections_from_generic(job)

        raise RuntimeError(f'Unknown job type: {job}')
