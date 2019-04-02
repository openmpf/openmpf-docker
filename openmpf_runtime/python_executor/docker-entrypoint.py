#! /usr/bin/env python
from __future__ import print_function, division

import base64
import collections
import errno
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
import urllib2


def main():
    # Environment variables that are required at runtime
    wfm_user = os.getenv('WFM_USER')
    wfm_password = os.getenv('WFM_PASSWORD')

    # Optional configurable environment variables
    wfm_base_url = os.getenv('WFM_BASE_URL', 'http://workflow_manager:8080/workflow-manager')
    activemq_host = os.getenv('ACTIVE_MQ_HOST', 'activemq')
    component_log_name = os.getenv('COMPONENT_LOG_NAME')
    disable_component_registration = os.getenv('DISABLE_COMPONENT_REGISTRATION')
    node_name = os.getenv('THIS_MPF_NODE')

    # Environment variables from base Docker image
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
    base_log_path = os.getenv('MPF_LOG_PATH', os.path.join(mpf_home, 'share/logs'))


    descriptor_path = os.path.join(mpf_home, 'plugins/plugin/descriptor/descriptor.json')

    if disable_component_registration:
        print('Component registration disabled because the '
              '"DISABLE_COMPONENT_REGISTRATION" environment variable was set.')
    else:
        register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password)

    with open(descriptor_path, 'r') as descriptor_file:
        descriptor = json.load(descriptor_file)

    if not node_name:
        component_name = descriptor['componentName']
        node_name = '{}_id_{}'.format(component_name, os.getenv('HOSTNAME'))
    log_dir = os.path.join(base_log_path, node_name, 'log')

    executor_proc = start_executor(descriptor, mpf_home, activemq_host, node_name)
    tail_proc = tail_log(log_dir, component_log_name, executor_proc.pid)

    exit_code = executor_proc.wait()
    tail_proc.wait()

    print('Executor exit code =', exit_code)
    sys.exit(exit_code)



def register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password):
    if not wfm_user or not wfm_password:
        raise RuntimeError('The WFM_USER and WFM_PASSWORD environment variables must both be set.')

    url = wfm_base_url + '/rest/components/registerUnmanaged'
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(wfm_user + ':' + wfm_password),
        'Content-Length': os.stat(descriptor_path).st_size,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    ssl_ctx.verify_mode = ssl.CERT_NONE

    print('Registering component by posting', descriptor_path, 'to', url)
    try:
        post_descriptor_with_retry(descriptor_path, url, headers, ssl_ctx)
    except urllib2.HTTPError as err:
        handle_registration_error(err)


def post_descriptor_with_retry(descriptor_path, url, headers, ssl_ctx):
    while True:
        try:
            post_descriptor(descriptor_path, url, headers, ssl_ctx)
            return
        except urllib2.HTTPError as err:
            if err.url != url:
                # This generally means the provided WFM url used HTTP, but WFM was configured to use HTTPS
                print('Initial registration response failed. Trying with redirected url: ', err.url)
                post_descriptor(descriptor_path, err.url, headers, ssl_ctx)
                return
            if err.code != 404:
                raise
            print('Registration failed due to "{}". This is either because Tomcat has started, but the '
                  'Workflow Manager is still deploying or because the wrong URL was used for the WFM_BASE_URL '
                  'environment variable. Registration will be re-attempted in 5 seconds.'.format(err))
        except urllib2.URLError as err:
            reason = err.reason
            should_retry = (isinstance(reason, socket.gaierror) and reason.errno == socket.EAI_NONAME
                            or isinstance(reason, socket.error) and reason.errno == errno.ECONNREFUSED)
            if not should_retry:
                raise
            print('Registration failed due to "{}". This is either because the Workflow Manager is still starting or '
                  'because the wrong URL was used for the WFM_BASE_URL environment variable. Registration will '
                  'be re-attempted in 5 seconds.'.format(reason.strerror))
        time.sleep(5)


def post_descriptor(descriptor_path, url, headers, ssl_ctx):
    with open(descriptor_path, 'r') as descriptor_file:
        request = urllib2.Request(url, descriptor_file, headers=headers)
        response = urllib2.urlopen(request, context=ssl_ctx).read()
        print('Registration response:', response)


def handle_registration_error(http_error):
    import traceback
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
    amq_detection_component_path = os.path.join(mpf_home, 'bin/amq_detection_component')
    activemq_broker_uri = 'failover://(tcp://{}:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1'\
                          .format(activemq_host)
    batch_lib = descriptor['batchLibrary']
    algorithm_name = descriptor['algorithm']['name'].upper()
    queue_name = 'MPF.DETECTION_{}_REQUEST'.format(algorithm_name)

    executor_command = (amq_detection_component_path, activemq_broker_uri, batch_lib, queue_name, 'python')
    print('Starting component executor with command:', format_command_list(executor_command))
    executor_proc = subprocess.Popen(executor_command,
                                     env=get_executor_env_vars(mpf_home, descriptor, node_name),
                                     cwd=os.path.join(mpf_home, 'plugins/plugin'),
                                     stdin=subprocess.PIPE)

    # Handle ctrl-c
    signal.signal(signal.SIGINT, lambda sig, frame: stop_executor(executor_proc))
    # Handle docker stop
    signal.signal(signal.SIGTERM, lambda sig, frame: stop_executor(executor_proc))
    return executor_proc


def stop_executor(executor_proc):
    still_running = executor_proc.poll() is None
    if still_running:
        print('Sending quit to component executor')
        # Write "q\n" to executor's stdin to request orderly shutdown.
        executor_proc.communicate('q\n')


def tail_log(log_dir, component_log_name, executor_pid):
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)

    detection_log_file = os.path.join(log_dir, 'detection.log')
    if component_log_name:
        component_log_file = os.path.join(log_dir, component_log_name)
        log_files = (detection_log_file, component_log_file)
    else:
        print('WARNING: No component log file specified. Only component executor\'s log will appear')
        log_files = (detection_log_file,)

    for log_file in log_files:
        if not os.path.exists(log_file):
            # Create file if it doesn't exist.
            open(log_file, 'a').close()

    tail_command = (
        'tail',
        # Follow by name to handle log rollover.
        '--follow=name',
        # Watch executor process and exit when executor exists.
        '--pid', str(executor_pid),
        # Don't output file name headers which tail does by default when tailing multiple files.
        '--quiet') + log_files

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

    mpf_lib_path = os.path.join(mpf_home, 'lib')
    executor_env['LD_LIBRARY_PATH'] = executor_env.get('LD_LIBRARY_PATH', '') + ':' + mpf_lib_path
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

