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

import array
import collections
import enum
import os
import socket
import string
from types import ModuleType
from typing import Iterator, Mapping, Optional, Protocol, ClassVar, Iterable, Tuple

# A leading zero byte indicates an address in Linux’s abstract namespace.
# The address in a regular unix socket corresponds to a name that appears in the filesystem. That
# socket file can not be bound to a second time, even if the process that created it has exited.
# If the server stopped and then was started again, it would have to delete that socket file before
# binding to it. This can create a race condition if multiple instances of the server were started
# at the same time. Using an abstract prevents these issues because it is automatically removed
# when the process exits.
SOCKET_ADDRESS = b'\x00mpf_cli_runner.sock'


class MediaType(enum.Enum):
    IMAGE = enum.auto()
    VIDEO = enum.auto()
    AUDIO = enum.auto()
    GENERIC = enum.auto()


class ComponentHandle(Protocol):
    """
    Manages the lifetime of a language-specific component.
    """

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


def get_idle_timeout() -> Optional[int]:
    default_idle_timeout = 60
    env_val_str = os.getenv('COMPONENT_SERVER_IDLE_TIMEOUT')
    if not env_val_str:
        return default_idle_timeout
    try:
        env_val_int = int(env_val_str)
        if env_val_int >= 0:
            return env_val_int
        else:
            return None
    except ValueError:
        return default_idle_timeout


# From https://docs.python.org/3/library/socket.html#socket.socket.sendmsg
def send_fds(sock: socket.socket, *fds: int) -> int:
    # At least one byte of regular data must be sent with the file descriptors, so we send a
    # zero byte.
    return sock.sendmsg((b'\x00',), [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))])


def get_job_props_from_env(env: Mapping[str, str]) -> Iterator[Tuple[str, str]]:
    property_prefix = 'MPF_PROP_'
    for var_name, var_value in env.items():
        if len(var_name) > len(property_prefix) and var_name.startswith(property_prefix):
            prop_name = var_name[len(property_prefix):]
            yield prop_name, var_value
