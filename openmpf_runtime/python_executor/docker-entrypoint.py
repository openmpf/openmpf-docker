#! /usr/bin/env python

import base64
import json
import os
import signal
import subprocess
import sys
import time
import urllib2

def main():
    mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
    # Configurable environment variables
    wfm_base_url = os.getenv('WFM_BASE_URL', 'http://workflow_manager:8080/workflow-manager')
    activemq_host = os.getenv('ACTIVE_MQ_HOST', 'activemq')
    wfm_user = os.getenv('WFM_USER', 'admin')
    # TODO: remove default value
    wfm_password = os.getenv('WFM_PASSWORD', 'mpfadm')

    descriptor_path = os.path.join(mpf_home, 'plugins/plugin/descriptor/descriptor.json')
    register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password)
    run_executor(descriptor_path, mpf_home, activemq_host)



def register_component(descriptor_path, wfm_base_url, wfm_user, wfm_password):
    headers = {
        'Content-Length': os.stat(descriptor_path).st_size,
        'Authorization': 'Basic ' + base64.b64encode(wfm_user + ':' + wfm_password)
    }
    url = wfm_base_url + '/rest/components/registerUnmanaged'
    with open(descriptor_path, 'r') as descriptor_file:
        request = urllib2.Request(url, descriptor_file, headers=headers)
        response = urllib2.urlopen(request).read()
        print response


def tail_log(executor_pid):
    log_dir = os.path.join(os.getenv('MPF_LOG_PATH'), os.getenv('THIS_MPF_NODE'), 'log')
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    log_file = os.path.join(log_dir, 'detection.log')
    if not os.path.exists(log_file):
        # Create file if it doesn't exist
        open(log_file, 'a').close()
    # Use preexec_fn=os.setpgrp to prevent ctrl-c from killing tail since
    # executor may write to log file when shutting down.
    # TODO: Look in to --retry
    # TODO: Look in to --follow=name
    # TODO: Show component log. Maybe use --quiet so there is only one tail proc
    return subprocess.Popen(['tail', '--follow', '--pid', str(executor_pid), '--lines=+1', log_file],
                            preexec_fn=os.setpgrp)



def run_executor(descriptor_path, mpf_home, activemq_host):
    with open(descriptor_path, 'r') as descriptor_file:
        descriptor = json.load(descriptor_file)
    component_name = descriptor['componentName']
    algorithm_name = descriptor['algorithm']['name'].upper()
    queue_name = 'MPF.DETECTION_%s_REQUEST' % algorithm_name
    plugin_dir = os.path.join(mpf_home, 'plugins/plugin')

    executor_env_vars = os.environ.copy()
    executor_env_vars['SERVICE_NAME'] = component_name  # Executor errors out when this variable is not set.
    executor_env_vars['LD_LIBRARY_PATH'] \
        = executor_env_vars.get('LD_LIBRARY_PATH', '') + ':' + os.path.join(mpf_home, 'lib')

    activemq_broker_uri = 'failover://(tcp://%s:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1' \
                          % activemq_host

    amq_detection_component_path = os.path.join(mpf_home, 'bin/amq_detection_component')
    command = (amq_detection_component_path, activemq_broker_uri, component_name, queue_name, 'python')
    executor_proc = subprocess.Popen(command, env=executor_env_vars, cwd=plugin_dir, stdin=subprocess.PIPE)
    tail_proc = tail_log(executor_proc.pid)

    signal.signal(signal.SIGINT, lambda sig, frame: stop_executor(executor_proc))
    signal.signal(signal.SIGTERM, lambda sig, frame: stop_executor(executor_proc))

    exit_code = executor_proc.wait()
    # Should we give up after a second?
    tail_proc.wait()

    print 'Executor exit code =', exit_code
    sys.exit(exit_code)



def stop_executor(executor_proc):
    still_running = executor_proc.poll() is None
    if still_running:
        print 'Sending quit'
        # Write "q\n" to executor's stdin to request orderly shutdown.
        executor_proc.communicate('q\n')


if __name__ == '__main__':
    main()
