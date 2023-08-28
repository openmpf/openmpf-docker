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

import os
import contextlib
from typing import Any, Dict, Union, Iterable

import mpf_cpp_sdk
from mpf_cpp_sdk import ImageLocation, VideoTrack, AudioTrack, GenericTrack

import mpf_cli_runner_util as util


class CppComponentHandle(util.ComponentHandle, contextlib.AbstractContextManager):
    sdk_module = mpf_cpp_sdk

    def __init__(self, descriptor: Dict[str, Any]):
        self._configure_logging()
        batch_lib_path = util.expand_env_vars(descriptor['batchLibrary'], os.environ)
        try:
            self._component = mpf_cpp_sdk.CppComponent(batch_lib_path)
        except mpf_cpp_sdk.DlError as e:
            raise RuntimeError(
                f'{e}. The LD_LIBRARY_PATH environment variable may be set wrong. '
                'LD_LIBRARY_PATH must be set prior to starting the CLI runner.') from e

        mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
        self._component.SetRunDirectory(os.path.join(mpf_home, 'plugins'))

        if not self._component.Init():
            raise RuntimeError('The component failed to initialized.')

        self.track_type = descriptor['trackType']


    def __exit__(self, *exc_details):
        self._component.Close()


    def supports(self, media_type: util.MediaType) -> bool:
        if media_type == util.MediaType.IMAGE:
            return self._component.Supports(mpf_cpp_sdk.DetectionDataType.IMAGE)
        if media_type == util.MediaType.VIDEO:
            return self._component.Supports(mpf_cpp_sdk.DetectionDataType.VIDEO)
        if media_type == util.MediaType.AUDIO:
            return self._component.Supports(mpf_cpp_sdk.DetectionDataType.AUDIO)
        if media_type == util.MediaType.GENERIC:
            return self._component.Supports(mpf_cpp_sdk.DetectionDataType.UNKNOWN)
        return False


    def run_job(self, job) -> Union[Iterable[ImageLocation], Iterable[VideoTrack],
                                    Iterable[AudioTrack], Iterable[GenericTrack]]:
        return self._component.GetDetections(job)


    @staticmethod
    def _configure_logging():
        if 'LOG4CXX_CONFIGURATION' in os.environ:
            return
        log_config_path = os.path.join(os.path.dirname(__file__), 'Log4cxxConfig.xml')
        # The LOG4CXX library checks this environment variable when LOG4CXX is not explicitly
        # configured.
        os.environ['LOG4CXX_CONFIGURATION'] = log_config_path
