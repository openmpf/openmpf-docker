#!/usr/bin/env python3

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

from __future__ import annotations

import collections
import json
import os
import shlex
import signal
import string
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, NamedTuple, Optional, Tuple

import component_registration

Descriptor = Dict[str, Any]

def main():
    executor_proc, tail_proc = init()
    exit_code = executor_proc.wait()
    if tail_proc:
        tail_proc.wait()

    print('Executor exit code =', exit_code)
    sys.exit(exit_code)


class EnvConfig(NamedTuple):
    wfm_user: str
    wfm_password: str
    wfm_base_url: str
    oidc_issuer_uri: Optional[str]
    activemq_broker_uri: str
    component_log_name: Optional[str]
    disable_component_registration: bool
    node_name: Optional[str]
    mpf_home: Path
    base_log_path: Path

    @staticmethod
    def create():
        oidc_issuer_uri = os.getenv('OIDC_JWT_ISSUER_URI', os.getenv('OIDC_ISSUER_URI'))
        wfm_user = os.getenv('WFM_USER', None if oidc_issuer_uri else 'admin')
        wfm_password = os.getenv('WFM_PASSWORD', None if oidc_issuer_uri else 'mpfadm')
        if not wfm_user or not wfm_password:
            raise RuntimeError(
                'The WFM_USER and WFM_PASSWORD environment variables must both be set.')

        activemq_broker_uri = os.getenv('ACTIVE_MQ_BROKER_URI')
        if not activemq_broker_uri:
            activemq_host = os.getenv('ACTIVE_MQ_HOST', 'workflow-manager')
            activemq_broker_uri = f'failover:(tcp://{activemq_host}:61616)?maxReconnectAttempts=13'

        mpf_home = Path(os.getenv('MPF_HOME', '/opt/mpf'))
        if log_path_str := os.getenv('MPF_LOG_PATH'):
            log_path = Path(log_path_str)
        else:
            log_path = mpf_home / 'share/logs'
        return EnvConfig(
            wfm_user,
            wfm_password,
            os.getenv('WFM_BASE_URL', 'http://workflow-manager:8080'),
            oidc_issuer_uri,
            activemq_broker_uri,
            os.getenv('COMPONENT_LOG_NAME'),
            bool(os.getenv('DISABLE_COMPONENT_REGISTRATION')),
            os.getenv('THIS_MPF_NODE'),
            mpf_home,
            log_path)


def init() -> Tuple[subprocess.Popen[str], Optional[subprocess.Popen[bytes]]]:
    env_config = EnvConfig.create()

    descriptor_path = find_descriptor(env_config.mpf_home)
    print('Loading descriptor from', descriptor_path)
    with open(descriptor_path, 'rb') as descriptor_file:
        unparsed_descriptor = descriptor_file.read()

    if env_config.disable_component_registration:
        print('Component registration disabled because the '
              '"DISABLE_COMPONENT_REGISTRATION" environment variable was set.')
    else:
        component_registration.register_component(env_config, unparsed_descriptor)

    descriptor = json.loads(unparsed_descriptor)
    if env_config.node_name:
        node_name = env_config.node_name
    else:
        component_name = descriptor['componentName']
        node_name = f'{component_name}_id_{os.getenv("HOSTNAME")}'
    log_dir = env_config.base_log_path / node_name / 'log'

    executor_proc = start_executor(
        descriptor, env_config.mpf_home, env_config.activemq_broker_uri, node_name)
    tail_proc = tail_log_if_needed(log_dir, env_config.component_log_name, executor_proc.pid)

    return executor_proc, tail_proc


def find_descriptor(mpf_home: Path) -> Path:
    glob_subpath = 'plugins/*/descriptor/descriptor.json'
    glob_matches = list(mpf_home.glob(glob_subpath))
    if len(glob_matches) == 1:
        return glob_matches[0]

    glob_pattern = str(mpf_home / glob_subpath)
    if len(glob_matches) == 0:
        raise RuntimeError(
            f'Expecting to find a descriptor file at "{glob_pattern}", but it was not there.')

    if all(glob_matches[0].samefile(m) for m in glob_matches[1:]):
        return glob_matches[0]

    raise RuntimeError(
        f'Expected to find one descriptor matching "{glob_pattern}", but the following '
        f'descriptors were found: {glob_matches}')


def start_executor(descriptor: Descriptor, mpf_home: Path, activemq_broker_uri: str, node_name: str
                   ) -> subprocess.Popen[str]:
    algorithm_name = descriptor['algorithm']['name'].upper()
    queue_name = f'MPF.DETECTION_{algorithm_name}_REQUEST'
    language = descriptor['sourceLanguage'].lower()

    executor_env = get_executor_env_vars(mpf_home, descriptor, node_name)
    if language in ('c++', 'python'):
        amq_detection_component_path = str(mpf_home / 'bin/amq_detection_component')
        batch_lib = expand_env_vars(descriptor['batchLibrary'], executor_env)
        executor_command = (
            amq_detection_component_path, activemq_broker_uri, batch_lib, queue_name, language)

    elif language == 'java':
        executor_jar = find_java_executor_jar(descriptor, mpf_home)
        component_jar = (
            mpf_home / 'plugins' / descriptor['componentName'] / descriptor['batchLibrary'])
        class_path = f'{executor_jar}:{component_jar}'
        executor_command = ('java', '--class-path', class_path,
                            'org.mitre.mpf.component.executor.detection.MPFDetectionMain',
                            queue_name, activemq_broker_uri)
    else:
        raise RuntimeError(
            'Descriptor contained invalid sourceLanguage property. '
            'It must be c++, python, or java.')

    print('Starting component executor with command:', shlex.join(executor_command))
    executor_proc = subprocess.Popen(
        executor_command,
        env=executor_env,
        cwd=mpf_home / 'plugins' / descriptor['componentName'],
        stdin=subprocess.PIPE,
        text=True)

    # Handle ctrl-c
    signal.signal(signal.SIGINT, lambda sig, frame: stop_executor(executor_proc))
    # Handle docker stop
    signal.signal(signal.SIGTERM, lambda sig, frame: stop_executor(executor_proc))
    return executor_proc


def find_java_executor_jar(descriptor: Descriptor, mpf_home: Path) -> Path:
    jars_dir = mpf_home / 'jars'
    middleware_version = descriptor['middlewareVersion']
    executor_matching_version_path = (
        jars_dir / f'mpf-java-component-executor-{middleware_version}.jar')
    if executor_matching_version_path.exists():
        return executor_matching_version_path

    glob_subpath = 'mpf-java-component-executor-*.jar'
    glob_matches = list(jars_dir.glob(glob_subpath))
    if not glob_matches:
        executor_path_with_glob = str(jars_dir / glob_subpath)
        raise RuntimeError(
            f'Did not find the OpenMPF Java Executor jar at "{executor_path_with_glob}".')
    expanded_executor_path = glob_matches[0]
    print(f'WARNING: Did not find the OpenMPF Java Executor version "{middleware_version}" at '
          f'"{executor_matching_version_path}". Using "{expanded_executor_path}" instead.')
    return expanded_executor_path


def stop_executor(executor_proc: subprocess.Popen[str]) -> None:
    still_running = executor_proc.poll() is None
    if still_running:
        print('Sending quit to component executor')
        # Write "q\n" to executor's stdin to request orderly shutdown.
        executor_proc.stdin.write('q\n')
        executor_proc.stdin.flush()


def tail_log_if_needed(log_dir: Path, component_log_name: Optional[str], executor_pid: int
                       ) -> Optional[subprocess.Popen[bytes]]:
    if not component_log_name:
        return None

    log_dir.mkdir(parents=True, exist_ok=True)

    component_log_full_path = log_dir / component_log_name
    if not component_log_full_path.exists():
        # Create file if it doesn't exist.
        component_log_full_path.touch(exist_ok=True)

    tail_command = (
        'tail',
        # Follow by name to handle log rollover.
        '--follow=name',
        # Watch executor process and exit when executor exists.
        '--pid', str(executor_pid),
        str(component_log_full_path))

    print('Displaying logs with command: ', shlex.join(tail_command))
    # Use start_new_session to prevent ctrl-c from killing tail since
    # executor may write to log file when shutting down.
    return subprocess.Popen(tail_command, start_new_session=True)



def get_executor_env_vars(mpf_home: Path, descriptor: Descriptor, node_name: str) -> Dict[str, str]:
    executor_env = os.environ.copy()
    executor_env['THIS_MPF_NODE'] = node_name
    executor_env['SERVICE_NAME'] = descriptor['componentName']
    executor_env['COMPONENT_NAME'] = descriptor['componentName']

    for json_env_var in descriptor.get('environmentVariables', ()):
        var_name = json_env_var['name']
        var_value = expand_env_vars(json_env_var['value'], executor_env)
        sep = json_env_var.get('sep')

        existing_val = executor_env.get(var_name) if sep else None
        if sep and existing_val:
            executor_env[var_name] = existing_val + sep + var_value
        else:
            executor_env[var_name] = var_value

    ld_lib_path = executor_env.get('LD_LIBRARY_PATH', '')
    if ld_lib_path:
        ld_lib_path += ':'

    executor_env['LD_LIBRARY_PATH'] = ld_lib_path + str(mpf_home / 'lib')
    return executor_env


# Expand environment variables and replace non-existent variables with an empty string.
def expand_env_vars(raw_str: str, env: Dict[str, str]) -> str:
    # dict that returns empty string when key is missing.
    defaults = collections.defaultdict(str)
    # In the call to substitute the keyword arguments (**env) take precedence.
    return string.Template(raw_str).substitute(defaults, **env)


if __name__ == '__main__':
    main()
