#! /usr/bin/env python
from __future__ import print_function, division


import BaseHTTPServer
import json
import os

def main():
    server = BaseHTTPServer.HTTPServer(('', 8080), RequestHandler)
    server.serve_forever()


class RequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    error_content_type = 'application/json'
    error_message_format = '{"message": "%(message)s"}'

    def do_POST(self):
        try:
            content_len = int(self.headers.getheader('Content-Length'))
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
            f.write(post_body)

        self.send_response(200)
        self.end_headers()
        self.wfile.write('{"message": "Descriptor stored."}')


if __name__ == '__main__':
    main()
