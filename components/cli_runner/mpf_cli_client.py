#!/usr/bin/env python3

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2022 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2022 The MITRE Corporation                                      #
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

import os
import pickle
import socket
import sys

import mpf_cli_runner_util as util


def main():
    if len(sys.argv) == 2 and sys.argv[1] in ('-d', '--daemon'):
        import mpf_cli_server
        mpf_cli_server.main()
        return

    with socket.socket(socket.AF_UNIX) as sock:
        try:
            sock.connect(util.SOCKET_ADDRESS)
        except ConnectionRefusedError:
            import mpf_cli_server
            # Fork a server process.
            mpf_cli_server.start_from_client(sock)
            sock.connect(util.SOCKET_ADDRESS)

        util.send_fds(sock, sys.stdin.fileno(), sys.stdout.fileno(), sys.stderr.fileno())
        with sock.makefile('rwb') as sf:
            pickle.dump(sys.argv, sf)
            pickle.dump(os.getcwd(), sf)
            pickle.dump(dict(util.get_job_props_from_env(os.environ)), sf)
            sf.flush()
            response = sf.read(1)
    if response == b'':
        print('ERROR: Server closed connection before completing the job.', file=sys.stderr)
        sys.exit(6)
    else:
        sys.exit(response[0])


if __name__ == '__main__':
    main()
