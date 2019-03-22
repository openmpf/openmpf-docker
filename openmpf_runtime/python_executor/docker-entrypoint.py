#! /usr/bin/env python
from __future__ import print_function, division

import base64
import collections
import json
import os
import pipes
import signal
import string
import subprocess
import sys
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

    # Environment variables from base Docker image
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
    base_log_path = os.getenv('MPF_LOG_PATH', mpf_home + '/share/logs')
    node_name = os.getenv('THIS_MPF_NODE', 'python_executor')

    descriptor_path = os.path.join(mpf_home, 'plugins/plugin/descriptor/descriptor.json')
    log_dir = os.path.join(base_log_path, node_name, 'log')

    if disable_component_registration:
        print('Component registration disabled because the '
              '"DISABLE_COMPONENT_REGISTRATION" environment variable was set.')
    else:
        register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password)

    executor_proc = start_executor(descriptor_path, mpf_home, activemq_host)
    tail_proc = tail_log(log_dir, component_log_name, executor_proc.pid)

    exit_code = executor_proc.wait()
    # Should we give up after a second?
    tail_proc.wait()

    print('Executor exit code =', exit_code)
    sys.exit(exit_code)


def register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password):
    # TODO: Check wfm_user and wfm_password
    url = wfm_base_url + '/rest/components/registerUnmanaged'
    headers = {
        'Content-Length': os.stat(descriptor_path).st_size,
        'Authorization': 'Basic ' + base64.b64encode(wfm_user + ':' + wfm_password)
    }
    print('Registering component by posting', descriptor_path, 'to', url)
    with open(descriptor_path, 'r') as descriptor_file:
        request = urllib2.Request(url, descriptor_file, headers=headers)
        # TODO: handle descriptor validation and http errors
        # TODO: Check if http url gets redirected when WFM is using https
        response = urllib2.urlopen(request).read()
        print('Registration response:', response)


def start_executor(descriptor_path, mpf_home, activemq_host):
    with open(descriptor_path, 'r') as descriptor_file:
        descriptor = json.load(descriptor_file)

    amq_detection_component_path = os.path.join(mpf_home, 'bin/amq_detection_component')
    activemq_broker_uri = 'failover://(tcp://{}:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1'\
                          .format(activemq_host)
    component_name = descriptor['componentName']
    algorithm_name = descriptor['algorithm']['name'].upper()
    queue_name = 'MPF.DETECTION_{}_REQUEST'.format(algorithm_name)

    executor_command = (amq_detection_component_path, activemq_broker_uri, component_name, queue_name, 'python')
    print('Starting component executor with command:', format_command_list(executor_command))
    executor_proc = subprocess.Popen(executor_command,
                                     env=get_executor_env_vars(mpf_home, descriptor),
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
        log_files = (detection_log_file, )

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
        # Start by outputting any lines already in file in case log messages get written before tail starts.
        '--lines=+1',
        # Don't output file name headers which tail does by default when tailing multiple files.
        '--quiet') + log_files

    print('Displaying logs with command: ', format_command_list(tail_command))
    # Use preexec_fn=os.setpgrp to prevent ctrl-c from killing tail since
    # executor may write to log file when shutting down.
    return subprocess.Popen(tail_command, preexec_fn=os.setpgrp)



def get_executor_env_vars(mpf_home, descriptor):
    executor_env = os.environ.copy()
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
