#! /usr/bin/env python
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

from __future__ import print_function, division

import base64
import errno
import fnmatch
import httplib
import json
import os
import pipes
import signal
import socket
import ssl
import subprocess
import sys
import time
import urllib2


def main():
    # Environment variables that are required at runtime
    wfm_user = os.getenv('WFM_USER')
    wfm_password = os.getenv('WFM_PASSWORD')

    # Optional configurable environment variables
    wfm_base_url = os.getenv('WFM_BASE_URL', 'http://workflow_manager:8080/workflow-manager')

    if not wfm_user or not wfm_password:
        raise RuntimeError('The WFM_USER and WFM_PASSWORD environment variables must both be set.')

    url = wfm_base_url + '/rest/info'
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(wfm_user + ':' + wfm_password)
    }
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    ssl_ctx.verify_mode = ssl.CERT_NONE

    print('Checking if Workflow Manager is running by accessing', url)
    try:
        get_info_with_retry(url, headers, ssl_ctx)
    except urllib2.HTTPError as err:
        handle_get_info_error(err)

    this_mpf_node = os.getenv('THIS_MPF_NODE')
    hostname = os.getenv('HOSTNAME')
    node_name = '{}_id_{}'.format(this_mpf_node, hostname)

    # with open('/etc/profile.d/mpf.sh', 'a') as profile:
    #    profile.write('export THIS_MPF_NODE=' + node_name)
    #    profile.write('export JGROUPS_TCP_ADDRESS=' + hostname)

    # Environment variables from base Docker image
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
    base_log_path = os.getenv('MPF_LOG_PATH', os.path.join(mpf_home, 'share/logs'))

    log_dir = os.path.join(base_log_path, node_name, 'log')

    node_manager_proc = start_node_manager(mpf_home, node_name, hostname)
    tail_proc = tail_log(log_dir, node_manager_proc.pid)

    exit_code = node_manager_proc.wait()
    tail_proc.wait()

    print('node-manager exit code =', exit_code)
    sys.exit(exit_code)


def get_info_with_retry(url, headers, ssl_ctx):
    while True:
        try:
            get_info(url, headers, ssl_ctx)
            return
        except httplib.BadStatusLine:
            new_url = url.replace('http://', 'https://')
            print('Initial check failed due to an invalid status line in the HTTP response. '
                  'This usually means that the server is using HTTPS, but an "http://" URL was used. '
                  'Trying again with:', new_url)
            get_info(new_url, headers, ssl_ctx)
            return

        except urllib2.HTTPError as err:
            if err.url != url:
                # This generally means the provided WFM url used HTTP, but WFM was configured to use HTTPS
                print('Initial check failed. Trying with redirected url: ', err.url)
                get_info(err.url, headers, ssl_ctx)
                return
            if err.code != 404:
                raise
            print('Check failed due to "{}". This is either because Tomcat has started, but the '
                  'Workflow Manager is still deploying or because the wrong URL was used for the WFM_BASE_URL '
                  'environment variable. Check will be re-attempted in 5 seconds.'.format(err))

        except urllib2.URLError as err:
            reason = err.reason
            should_retry_immediately = isinstance(reason, ssl.SSLError) and reason.reason == 'UNKNOWN_PROTOCOL'
            if should_retry_immediately:
                new_url = url.replace('https://', 'http://')
                print('Initial check failed due to an "UNKNOWN_PROTOCOL" SSL error. '
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
            print('Check failed due to "{}". This is either because the Workflow Manager is still starting or '
                  'because the wrong URL was used for the WFM_BASE_URL environment variable. Check will '
                  'be re-attempted in 5 seconds.'.format(reason.strerror))
        time.sleep(5)


def get_info(url, headers, ssl_ctx):
    request = urllib2.Request(url, headers=headers)
    response = urllib2.urlopen(request, context=ssl_ctx).read()
    print('Get info response:', response)


def handle_get_info_error(http_error):
    import traceback
    traceback.print_exc()
    print(file=sys.stderr)

    response_content = http_error.read()
    try:
        server_message = json.loads(response_content)['message']
    except (ValueError,  KeyError):
        server_message = response_content

    error_msg = 'The following error occurred while trying to get info: {}: {}' \
                .format(http_error, server_message)
    if http_error.code == 401:
        error_msg += '\nThe WFM_USER and WFM_PASSWORD environment variables need to be changed.'
    raise RuntimeError(error_msg)


def start_node_manager(mpf_home, node_name, hostname):
    jar_files = find_files(os.path.join(mpf_home, 'jars'), 'mpf-nodemanager-*.jar')
    if len(jar_files) == 0:
        raise RuntimeError('Could not find: ' + os.path.join(mpf_home, 'jars', 'mpf-nodemanager-*.jar'))

    if len(jar_files) > 0:
        raise RuntimeError('Found multiple node-manager jars: ' + ', '.join(jar_files))

    java_bin = os.path.join(os.getenv('JAVA_HOME'), '/bin/java')

    # jar process will manage its own log; log will be rotated every night at midnight
    # nohup  ${javabin} -jar ${jarfile} > /dev/null & #2>&1 #now displaying std err

    node_manager_command = (java_bin, '-jar', jar_files[0])
    print('Starting node-manager with command:', format_command_list(node_manager_command))
    node_manager_proc = subprocess.Popen(node_manager_command,
                                     env=get_node_manager_env_vars(node_name, hostname),
                                     cwd='/', # node-manager might cwd when it executes a service
                                     stdin=subprocess.PIPE)

    # Handle ctrl-c
    signal.signal(signal.SIGINT, lambda sig, frame: stop_node_manager(node_manager_proc))
    # Handle docker stop
    signal.signal(signal.SIGTERM, lambda sig, frame: stop_node_manager(node_manager_proc))
    return node_manager_proc


def stop_node_manager(node_manager_proc):
    still_running = node_manager_proc.poll() is None
    if still_running:
        print('Killing node-manager')
        node_manager_proc.kill()


def find_files(base, pattern):
    '''Return list of files matching pattern in base folder.'''
    return [n for n in fnmatch.filter(os.listdir(base), pattern) if
            os.path.isfile(os.path.join(base, n))]


def tail_log(log_dir, node_manager_pid):
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)

    node_log_file = os.path.join(log_dir, 'node-manager.log')

    if not os.path.exists(node_log_file):
        # Create file if it doesn't exist.
        open(node_log_file, 'a').close()

    tail_command = (
                       'tail',
                       # Follow by name to handle log rollover.
                       '--follow=name',
                       # Watch node-manager process and exit when node-manager exits.
                       '--pid', str(node_manager_pid)) + node_log_file

    print('Displaying log with command: ', format_command_list(tail_command))
    # Use preexec_fn=os.setpgrp to prevent ctrl-c from killing tail since
    # node-manager may write to log file when shutting down.
    return subprocess.Popen(tail_command, preexec_fn=os.setpgrp)


def get_node_manager_env_vars(node_name, hostname):
    node_manager_env = os.environ.copy()
    node_manager_env['THIS_MPF_NODE'] = node_name
    node_manager_env['JGROUPS_TCP_ADDRESS'] = hostname
    return node_manager_env


def format_command_list(command):
    # Makes sure any arguments with spaces are quoted.
    return ' '.join(map(pipes.quote, command))


if __name__ == '__main__':
    main()

