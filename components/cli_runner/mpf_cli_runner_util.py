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

import collections
import enum
import string
from types import ModuleType
from typing import Mapping, Protocol, ClassVar, Iterable


class MediaType(enum.Enum):
    IMAGE = enum.auto()
    VIDEO = enum.auto()
    AUDIO = enum.auto()
    GENERIC = enum.auto()


class ComponentHandle(Protocol):
    """
    Manages the lifetime of a language-specific component.
    """

    # The type of detection produced by the component.
    detection_type: str

    # A reference to the module containing the MPF job and result objects.
    # The classes and fields are named identically in mpf_cpp_sdk and mpf_component_api so the
    # common runner code can use them interchangeably.
    sdk_module: ClassVar[ModuleType]

    def supports(self, media_type: MediaType) -> bool:
        """
        Indicates whether or not the component supports the given media type.
        :param media_type: Media type to inquire about
        :return: True if the component can process the given media type, otherwise False.
        """
        ...

    def run_job(self, job) -> Iterable:
        """
        Invokes the component code to run the given job.
        :param job: The language-specific (C++ or Python) job object describing the job.
        :return: An iterable containing the results of running the component on the given job.
                 Contents of result iterable are dependent on the job type and component language.
        """
        ...


def expand_env_vars(raw_str: str, env: Mapping[str, str]) -> str:
    # dict that returns empty string when key is missing.
    defaults = collections.defaultdict(str)
    # In the call to substitute the keyword arguments (**env) take precedence.
    return string.Template(raw_str).substitute(defaults, **env)
