#! /bin/bash

set -e
set -x


if [ ! -e /home/mpf/component_src/setup.py ]; then
    echo 'Error expected /home/mpf/component_src/setup.py to exist'
    exit 4
fi

mkdir -p "$MPF_HOME/plugins/plugin"
cp -r /home/mpf/component_src/plugin-files/* "$MPF_HOME/plugins/plugin/"


if [ -d /home/mpf/component_src/plugin-files/wheelhouse ]; then
    "$COMPONENT_VIRTUALENV/bin/pip" install \
        --find-links /home/mpf/component_src/plugin-files/wheelhouse \
        --no-cache-dir /home/mpf/component_src
else
    "$COMPONENT_VIRTUALENV/bin/pip" install \
        --no-cache-dir /home/mpf/component_src
fi
