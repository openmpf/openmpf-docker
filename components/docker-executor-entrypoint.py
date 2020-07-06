#!/usr/bin/env python3

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
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

import base64
import collections
import errno
import glob
import http.client
import json
import os
import pipes
import signal
import socket
import ssl
import string
import subprocess
import sys
import time
import traceback
import urllib.error
import urllib.request


def main():
    executor_proc, tail_proc = init()
    exit_code = executor_proc.wait()
    if tail_proc:
        tail_proc.wait()

    print('Executor exit code =', exit_code)
    sys.exit(exit_code)


def init():
    # Optional configurable environment variables
    wfm_user = os.getenv('WFM_USER', 'admin')
    wfm_password = os.getenv('WFM_PASSWORD', 'mpfadm')
    wfm_base_url = os.getenv('WFM_BASE_URL', 'http://workflow-manager:8080/workflow-manager')
    activemq_host = os.getenv('ACTIVE_MQ_HOST', 'activemq')
    component_log_name = os.getenv('COMPONENT_LOG_NAME')
    disable_component_registration = os.getenv('DISABLE_COMPONENT_REGISTRATION')
    node_name = os.getenv('THIS_MPF_NODE')

    # Environment variables from base Docker image
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
    base_log_path = os.getenv('MPF_LOG_PATH', os.path.join(mpf_home, 'share/logs'))


    descriptor_path = find_descriptor(mpf_home)
    print('Loading descriptor from', descriptor_path)
    with open(descriptor_path, 'rb') as descriptor_file:
        unparsed_descriptor = descriptor_file.read()

    if disable_component_registration:
        print('Component registration disabled because the '
              '"DISABLE_COMPONENT_REGISTRATION" environment variable was set.')
    else:
        register_component(unparsed_descriptor, wfm_base_url, wfm_user, wfm_password)

    wait_for_activemq(activemq_host)

    descriptor = json.loads(unparsed_descriptor)
    if not node_name:
        component_name = descriptor['componentName']
        node_name = '{}_id_{}'.format(component_name, os.getenv('HOSTNAME'))
    log_dir = os.path.join(base_log_path, node_name, 'log')

    executor_proc = start_executor(descriptor, mpf_home, activemq_host, node_name)
    tail_proc = tail_log_if_needed(log_dir, component_log_name, descriptor['sourceLanguage'].lower(),
                                   executor_proc.pid)

    return executor_proc, tail_proc


def find_descriptor(mpf_home):
    glob_pattern = os.path.join(mpf_home, 'plugins/*/descriptor/descriptor.json')
    glob_matches = glob.glob(glob_pattern)
    if len(glob_matches) == 1:
        return glob_matches[0]
    if len(glob_matches) == 0:
        raise RuntimeError('Expecting to find a descriptor file at "{}", but it was not there.'
                           .format(glob_pattern))

    if all(os.path.samefile(glob_matches[0], m) for m in glob_matches[1:]):
        return glob_matches[0]

    raise RuntimeError('Expected to find one descriptor matching "{}", but the following descriptors were found: {}'
                       .format(glob_pattern, glob_matches))


def wait_for_activemq(activemq_host):
    while True:
        try:
            conn = http.client.HTTPConnection(activemq_host, 8161)
            conn.request('HEAD', '/')
            resp = conn.getresponse()
            if 200 <= resp.status <= 299:
                return
            print('Received non-success status code of {} when trying to connect to ActiveMQ. '
                  'This is either because ActiveMQ is still starting or the wrong host name was used for the '
                  'ACTIVE_MQ_HOST(={}) environment variable. Connection to ActiveMQ will re-attempted in 5 seconds.'
                  .format(resp.status, activemq_host))
        except socket.error as e:
            print('Attempt to connect to ActiveMQ failed due to "{}". This is either because ActiveMQ is still '
                  'starting or the wrong host name was used for the ACTIVE_MQ_HOST(={}) environment variable. '
                  'Connection to ActiveMQ will re-attempted in 5 seconds.'.format(e, activemq_host))
        time.sleep(5)



def register_component(unparsed_descriptor, wfm_base_url, wfm_user, wfm_password):
    if not wfm_user or not wfm_password:
        raise RuntimeError('The WFM_USER and WFM_PASSWORD environment variables must both be set.')

    auth_info_bytes = (wfm_user + ':' + wfm_password).encode('utf-8')
    base64_bytes = base64.b64encode(auth_info_bytes)
    headers = {
        'Authorization': 'Basic ' + base64_bytes.decode('utf-8'),
        'Content-Length': len(unparsed_descriptor),
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    url = wfm_base_url + '/rest/components/registerUnmanaged'
    print('Registering component by posting descriptor to', url)
    try:
        post_descriptor_with_retry(unparsed_descriptor, url, headers)
    except urllib.error.HTTPError as err:
        handle_registration_error(err)


def post_descriptor_with_retry(unparsed_descriptor, url, headers):

    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    ssl_ctx.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(ThrowingRedirectHandler(), urllib.request.HTTPSHandler(context=ssl_ctx))

    while True:
        try:
            post_descriptor(unparsed_descriptor, url, headers, opener)
            return
        except http.client.BadStatusLine:
            new_url = url.replace('http://', 'https://')
            print('Initial registration response failed due to an invalid status line in the HTTP response. '
                  'This usually means that the server is using HTTPS, but an "http://" URL was used. '
                  'Trying again with:', new_url)
            post_descriptor(unparsed_descriptor, new_url, headers, opener)
            return

        except urllib.error.HTTPError as err:
            if err.url != url:
                # This generally means the provided WFM url used HTTP, but WFM was configured to use HTTPS
                print('Initial registration response failed. Trying with redirected url: ', err.url)
                post_descriptor(unparsed_descriptor, err.url, headers, opener)
                return
            if err.code != 404:
                raise
            print('Registration failed due to "{}". This is either because Tomcat has started, but the '
                  'Workflow Manager is still deploying or because the wrong URL was used for the WFM_BASE_URL(={}) '
                  'environment variable. Registration will be re-attempted in 5 seconds.'.format(err, url))

        except urllib.error.URLError as err:
            reason = err.reason
            should_retry_immediately = isinstance(reason, ssl.SSLError) and reason.reason == 'UNKNOWN_PROTOCOL'
            if should_retry_immediately:
                new_url = url.replace('https://', 'http://')
                print('Initial registration response failed due to an "UNKNOWN_PROTOCOL" SSL error. '
                      'This usually means that the server is using HTTP on the specified port, '
                      'but an "https://" URL was used. Trying again with:', new_url)
                url = new_url
                # continue since the post to new_url might cause a redirect which raises an error that can be
                # handled.
                continue
            should_retry_after_delay = (isinstance(reason, socket.gaierror) and reason.errno == socket.EAI_NONAME
                                        or isinstance(reason, socket.error) and reason.errno == errno.ECONNREFUSED)
            if not should_retry_after_delay:
                raise
            print('Registration failed due to "{}". This is either because the Workflow Manager is still starting or '
                  'because the wrong URL was used for the WFM_BASE_URL(={}) environment variable. Registration will '
                  'be re-attempted in 5 seconds.'.format(reason.strerror, url))
        time.sleep(5)


# The default urllib.request.HTTPRedirectHandler converts POST requests to GET requests.
# This subclass just throws an exception so we can post to the new URL ourselves.
class ThrowingRedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers):
        if 'location' in headers:
            new_url = headers['location']
        elif 'uri' in headers:
            new_url = headers['uri']
        else:
            raise RuntimeError('Received HTTP redirect response with no location header.')

        raise urllib.error.HTTPError(new_url, code, msg, headers, fp)


def post_descriptor(unparsed_descriptor, url, headers, opener):
    request = urllib.request.Request(url, unparsed_descriptor, headers=headers)
    with opener.open(request) as response:
        body = response.read()
    print('Registration response:', body)


def handle_registration_error(http_error):
    traceback.print_exc()
    print(file=sys.stderr)

    response_content = http_error.read()
    try:
        server_message = json.loads(response_content)['message']
    except (ValueError,  KeyError):
        server_message = response_content

    error_msg = 'The following error occurred while trying to register component: {}: {}' \
                .format(http_error, server_message)
    if http_error.code == 401:
        error_msg += '\nThe WFM_USER and WFM_PASSWORD environment variables need to be changed.'
    raise RuntimeError(error_msg)


def start_executor(descriptor, mpf_home, activemq_host, node_name):
    activemq_broker_uri = 'failover://(tcp://{}:61616)?jms.prefetchPolicy.all=0&startupMaxReconnectAttempts=1'\
                          .format(activemq_host)
    algorithm_name = descriptor['algorithm']['name'].upper()
    queue_name = 'MPF.DETECTION_{}_REQUEST'.format(algorithm_name)
    language = descriptor['sourceLanguage'].lower()

    executor_env = get_executor_env_vars(mpf_home, descriptor, node_name)
    if language in ('c++', 'python'):
        amq_detection_component_path = os.path.join(mpf_home, 'bin/amq_detection_component')
        batch_lib = expand_env_vars(descriptor['batchLibrary'], executor_env)
        executor_command = (amq_detection_component_path, activemq_broker_uri, batch_lib, queue_name, language)

    elif language == 'java':
        executor_jar = find_java_executor_jar(descriptor, mpf_home)
        component_jar = os.path.join(mpf_home, 'plugins', descriptor['componentName'], descriptor['batchLibrary'])
        class_path = executor_jar + ':' + component_jar
        executor_command = ('java', '--class-path', class_path,
                            'org.mitre.mpf.component.executor.detection.MPFDetectionMain',
                            queue_name, activemq_broker_uri)
    else:
        raise RuntimeError('Descriptor contained invalid sourceLanguage property. It must be c++, python, or java.')

    print('Starting component executor with command:', format_command_list(executor_command))
    executor_proc = subprocess.Popen(executor_command,
                                     env=executor_env,
                                     cwd=os.path.join(mpf_home, 'plugins', descriptor['componentName']),
                                     stdin=subprocess.PIPE,
                                     text=True)

    # Handle ctrl-c
    signal.signal(signal.SIGINT, lambda sig, frame: stop_executor(executor_proc))
    # Handle docker stop
    signal.signal(signal.SIGTERM, lambda sig, frame: stop_executor(executor_proc))
    return executor_proc


def find_java_executor_jar(descriptor, mpf_home):
    java_executor_path_pattern = os.path.join(mpf_home, 'jars', 'mpf-java-component-executor-{}.jar')
    middleware_version = descriptor['middlewareVersion']
    executor_matching_version_path = java_executor_path_pattern.format(middleware_version)
    if os.path.exists(executor_matching_version_path):
        return executor_matching_version_path

    executor_path_with_glob = java_executor_path_pattern.format('*')
    glob_matches = glob.glob(executor_path_with_glob)
    if not glob_matches:
        raise RuntimeError('Did not find the OpenMPF Java Executor jar at "{}".'.format(executor_path_with_glob))
    expanded_executor_path = glob_matches[0]
    print('WARNING: Did not find the OpenMPF Java Executor version "{}" at "{}". Using "{}" instead.'
          .format(middleware_version, executor_matching_version_path, expanded_executor_path))
    return expanded_executor_path


def stop_executor(executor_proc):
    still_running = executor_proc.poll() is None
    if still_running:
        print('Sending quit to component executor')
        # Write "q\n" to executor's stdin to request orderly shutdown.
        executor_proc.stdin.write('q\n')
        executor_proc.stdin.flush()


def tail_log_if_needed(log_dir, component_log_name, source_language, executor_pid):
    is_java = source_language == 'java'
    if is_java and not component_log_name:
        return None

    if not os.path.exists(log_dir):
        try:
            os.makedirs(log_dir)
        except OSError as e:
            # Two components may both try to create the directory at the same time,
            # so we ignore the error indicating that the directory already exists.
            if e.errno != errno.EEXIST:
                raise

    log_files = []
    if not is_java:
        log_files.append(os.path.join(log_dir, 'detection.log'))

    if component_log_name:
        log_files.append(os.path.join(log_dir, component_log_name))
    elif source_language == 'c++':
        print('WARNING: No component log file specified. Only component executor\'s log will appear.')

    for log_file in log_files:
        if not os.path.exists(log_file):
            # Create file if it doesn't exist.
            open(log_file, 'a').close()

    tail_command = [
        'tail',
        # Follow by name to handle log rollover.
        '--follow=name',
        # Watch executor process and exit when executor exists.
        '--pid', str(executor_pid),
        # Don't output file name headers which tail does by default when tailing multiple files.
        '--quiet'] + log_files

    print('Displaying logs with command: ', format_command_list(tail_command))
    # Use preexec_fn=os.setpgrp to prevent ctrl-c from killing tail since
    # executor may write to log file when shutting down.
    return subprocess.Popen(tail_command, preexec_fn=os.setpgrp)



def get_executor_env_vars(mpf_home, descriptor, node_name):
    executor_env = os.environ.copy()
    executor_env['THIS_MPF_NODE'] = node_name
    executor_env['SERVICE_NAME'] = descriptor['componentName']

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

    executor_env['LD_LIBRARY_PATH'] = ld_lib_path + os.path.join(mpf_home, 'lib')
    return executor_env


# Expand environment variables and replace non-existent variables with an empty string.
def expand_env_vars(raw_str, env):
    # dict that returns empty string when key is missing.
    defaults = collections.defaultdict(str)
    # In the call to substitute the keyword arguments (**env) take precedence.
    return string.Template(raw_str).substitute(defaults, **env)



def format_command_list(command):
    # Makes sure any arguments with spaces are quoted.
    return ' '.join(map(pipes.quote, command))


if __name__ == '__main__':
    main()
