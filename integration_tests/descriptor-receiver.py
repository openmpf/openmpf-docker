#! /usr/bin/env python3

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

import http.server
import json
import os

# Creates an endpoint where Docker components can register their descriptors for use in integration tests.
def main():
    http.server.HTTPServer.request_queue_size = 100
    server = http.server.HTTPServer(('', 8080), RequestHandler)
    server.serve_forever()

class RequestHandler(http.server.BaseHTTPRequestHandler):
    error_content_type = 'application/json'
    error_message_format = '{"message": "%(message)s"}'

    def do_POST(self):
        try:
            content_len = int(self.headers['Content-Length'])
            post_body = self.rfile.read(content_len)
            descriptor = json.loads(post_body)
            component_name = descriptor['componentName']
        except (ValueError, KeyError):
            self.send_error(400, 'Failed to parse component descriptor.')
            raise

        print('Received descriptor for', component_name)

        descriptor_dir = os.path.join(os.getenv('MPF_HOME', '/opt/mpf'), 'plugins', component_name, 'descriptor')

        if not os.path.exists(descriptor_dir):
            os.makedirs(descriptor_dir)

        descriptor_path = os.path.join(descriptor_dir, 'descriptor.json')
        if os.path.exists(descriptor_path):
            print('Replacing descriptor at:', descriptor_path)
        else:
            print('Saving descriptor at:', descriptor_path)

        with open(descriptor_path, 'w') as f:
            f.write(post_body.decode())

        self.send_response(200)
        self.end_headers()
        self.wfile.write('{"message": "Descriptor stored."}'.encode())


if __name__ == '__main__':
    main()
