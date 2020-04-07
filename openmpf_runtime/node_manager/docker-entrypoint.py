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
import glob
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
    # Optional configurable environment variables
    wfm_user = os.getenv('WFM_USER', 'admin')
    wfm_password = os.getenv('WFM_PASSWORD', 'mpfadm')
    wfm_base_url = os.getenv('WFM_BASE_URL', 'http://workflow_manager:8080/workflow-manager')

    # Environment variables from base Docker image
    this_mpf_node = os.getenv('THIS_MPF_NODE')
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')

    # Environment variables at runtime
    hostname = os.getenv('HOSTNAME')

    wait_for_workflow_manager(wfm_base_url, wfm_user, wfm_password)

    node_name = '{}_id_{}'.format(this_mpf_node, hostname)
    node_manager_proc = start_node_manager(mpf_home, node_name, hostname)

    exit_code = node_manager_proc.wait()

    print('node-manager exit code =', exit_code)
    sys.exit(exit_code)


def wait_for_workflow_manager(wfm_base_url, wfm_user, wfm_password):
    if not wfm_user or not wfm_password:
        raise RuntimeError('The WFM_USER and WFM_PASSWORD environment variables must both be set.')

    url = wfm_base_url + '/rest/info'
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(wfm_user + ':' + wfm_password)
    }
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    ssl_ctx.verify_mode = ssl.CERT_NONE

    print('Checking if Workflow Manager is running at', url)
    try:
        get_info_with_retry(url, headers, ssl_ctx)
    except urllib2.HTTPError as err:
        handle_get_info_error(err)


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
    node_manager_command = ('java', '-jar', find_node_manager_jar(mpf_home))
    print('Starting node-manager with command:', format_command_list(node_manager_command))
    node_manager_proc = subprocess.Popen(node_manager_command,
                                         env=get_node_manager_env_vars(node_name, hostname),
                                         cwd='/')  # node-manager might cwd when it executes a service

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


def find_node_manager_jar(mpf_home):
    node_manager_path_with_glob = os.path.join(mpf_home, 'jars', 'mpf-nodemanager-*.jar')
    glob_matches = glob.glob(node_manager_path_with_glob)
    if not glob_matches:
        raise RuntimeError('Did not find the OpenMPF Node Manager jar at "{}".'.format(node_manager_path_with_glob))
    return glob_matches[0]


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

