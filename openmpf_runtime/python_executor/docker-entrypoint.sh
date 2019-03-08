#! /bin/bash


set -e

function stop_executor() {
    # If the executor is still running, write "q\n" to executor's stdin to request orderly shutdown.
    ps -p "$executor_pid" > /dev/null && {
        echo 'Sending quit'
        echo 'q' >> "$executor_std_in"
        echo 'Quit sent. Waiting for exit'
    }
    wait_for_executor_exit
}


function wait_for_executor_exit() {
    set +e
    wait "$executor_pid"
    executor_exit_status=$?
    # It takes a short amount of time for the log messages to actually show up
    sleep 1
    echo "Executor exited with status: $executor_exit_status"
    exit "$executor_exit_status"
}

#set -x

# Variables that can be optionally set using -e when calling docker run
WFM_BASE_URL=${WFM_BASE_URL:-http://workflow_manager:8080/workflow-manager}
ACTIVE_MQ_HOST=${ACTIVE_MQ_HOST:-activemq}

# Local variables
active_mq_broker_uri="failover://(tcp://$ACTIVE_MQ_HOST:61616)?jms.prefetchPolicy.all=1&startupMaxReconnectAttempts=1"
descriptor_path="$MPF_HOME/plugins/plugin/descriptor/descriptor.json"
#component_name=$("$MPF_HOME/plugins/plugin/venv/bin/python" /home/mpf/component_src/setup.py --name)
component_name=$(python -c "import json; print json.load(open('$descriptor_path'))['componentName']")
algorithm_name=$(python -c "import json; print json.load(open('$descriptor_path'))['algorithm']['name'].upper()")
queue_name="MPF.DETECTION_${algorithm_name}_REQUEST"
executor_std_in=/tmp/amq_detection_component_std_in_file


curl --verbose --user admin:mpfadm -F "file=@$descriptor_path" "$WFM_BASE_URL/rest/components/registerUnmanaged"

mkdir -p "$MPF_LOG_PATH/$THIS_MPF_NODE/log"
touch "$MPF_LOG_PATH/$THIS_MPF_NODE/log/detection.log"
tail -f "$MPF_LOG_PATH/$THIS_MPF_NODE/log/detection.log" &

# Install the component and any remaining dependencies. The Python SDK libraries were already installed in Dockerfile.
# Use install -e to improve startup time by sym-linking to the component code rather than creating the whl file.
#"$MPF_HOME/plugins/plugin/venv/bin/pip" install -e "/component"


cd "$MPF_HOME/plugins/plugin"


export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$MPF_HOME/lib"

touch "$executor_std_in"
export SERVICE_NAME="$component_name" # Executor errors out when this variable is not set.

# Component executor looks for 'q\n' on stdin in order to initiate an orderly shutdown.
# Redirect component executors stdin to a file and use '&' to start background job so that we can use ctrl-c to
# initiate an orderly shutdown rather than killing it.
"$MPF_HOME/bin/amq_detection_component" "$active_mq_broker_uri" "$component_name" "$queue_name" "python" < "$executor_std_in" &
executor_pid=$!

trap stop_executor SIGINT SIGTERM
wait_for_executor_exit

