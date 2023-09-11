#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2023 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2023 The MITRE Corporation                                      #
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

import base64
import errno
import http.client
import json
import socket
import ssl
import time
import urllib.error
import urllib.request
import urllib.response
from typing import Callable, Dict, NoReturn, Tuple


def register_component(env_config, descriptor_bytes: bytes) -> None:
    if env_config.oidc_issuer_uri:
        OidcRegistration(env_config, descriptor_bytes
                         ).post_descriptor()
    else:
        BasicAuthRegistration(env_config, descriptor_bytes
                              ).post_descriptor()


def execute_http_request_with_retry(
        url: str,
        request_builder: Callable[[str], urllib.request.Request]) -> urllib.response.addinfourl:
    while True:
        request = request_builder(url)
        try:
            return _OPENER.open(request)
        except http.client.BadStatusLine as err:
            url = handle_bad_status(url, err)
        except urllib.error.HTTPError as err:
            url = handle_http_error(url, err)
        except urllib.error.URLError as err:
            url, should_wait = handle_url_error(url, err)
            if should_wait:
                time.sleep(10)


def handle_bad_status(url: str, error: http.client.BadStatusLine) -> str:
    if url.startswith('https'):
        raise error
    new_url = url.replace('http://', 'https://')
    print(f'HTTP request to {url} failed due to an invalid status line in the HTTP '
            'response. This usually means that the server is using HTTPS, but an "http://" '
            'URL was used. Trying again with:', new_url)
    return new_url


def handle_http_error(url: str, error: urllib.error.HTTPError) -> str:
    if error.url != url:
        print(f'Sending HTTP request to {url} resulted in a redirect to {error.url}.')
        return error.url

    response_content = error.read()
    try:
        server_message = json.loads(response_content)['message']
    except (ValueError,  KeyError):
        server_message = response_content

    error_msg = (f'The following error occurred while sending HTTP request to {url}: '
                f'{error}: {server_message}')
    if error.code == 401:
        error_msg += '\nThe WFM_USER and WFM_PASSWORD environment variables need to be changed.'
    raise RuntimeError(error_msg) from error


_RETRYABLE_ERR_NOS = (socket.EAI_NONAME, socket.EAI_AGAIN, errno.ECONNREFUSED)

def handle_url_error(url: str, error: urllib.error.URLError) -> Tuple[str, bool]:
    reason = error.reason
    is_unknown_protocol = isinstance(reason, ssl.SSLError) and reason.reason == 'UNKNOWN_PROTOCOL'
    if is_unknown_protocol:
        if url.startswith('http'):
            raise error
        new_url = url.replace('https://', 'http://')
        print(f'HTTP request to {url} failed due to an "UNKNOWN_PROTOCOL" SSL '
                'error. This usually means that the server is using HTTP on the specified '
                'port, but an "https://" URL was used. Trying again with:', new_url)
        return new_url, False

    if isinstance(reason, OSError) and reason.errno in _RETRYABLE_ERR_NOS:
        print(f'HTTP request to {url} failed due to "{reason.strerror}". This is either '
                'because the service is still starting up or the wrong URL was used. The '
                'request will be re-attempted in 10 seconds.')
        return url, True
    raise error



# The default urllib.request.HTTPRedirectHandler converts POST requests to GET requests.
# This subclass just throws an exception so we can post to the new URL ourselves.
class ThrowingRedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers) -> NoReturn:
        new_url = headers.get('location') or headers.get('uri')
        if new_url:
            raise urllib.error.HTTPError(new_url, code, msg, headers, fp)
        else:
            raise RuntimeError('Received HTTP redirect response with no location header.')


def create_opener() -> urllib.request.OpenerDirector:
    ssl_ctx = ssl.SSLContext()
    return urllib.request.build_opener(
        ThrowingRedirectHandler(),
        urllib.request.HTTPSHandler(context=ssl_ctx))

_OPENER = create_opener()


class BasicAuthRegistration:
    def __init__(self, env_config, descriptor_bytes: bytes):
        self._wfm_user: str = env_config.wfm_user
        self._wfm_password: str = env_config.wfm_password
        self._wfm_base_url: str = env_config.wfm_base_url
        self._descriptor_bytes: bytes = descriptor_bytes

    def post_descriptor(self) -> None:
        url = self._wfm_base_url + '/rest/components/registerUnmanaged'
        headers = create_basic_auth_header(self._wfm_user, self._wfm_password)
        headers['Content-Type'] = 'application/json'

        def create_request(url):
            return urllib.request.Request(url, self._descriptor_bytes, headers)

        print('Registering component by posting descriptor to', url)
        with execute_http_request_with_retry(url, create_request):
            # We don't need to do anything with the response.
            pass


class OidcRegistration:
    def __init__(self, env_config, descriptor_bytes: bytes):
        self._token_url: str = self._request_token_url(env_config.oidc_issuer_uri)
        self._token: str = ''
        self._reuse_token_until: float = 0.0
        self._wfm_base_url: str = env_config.wfm_base_url
        self._wfm_user: str = env_config.wfm_user
        self._wfm_password: str = env_config.wfm_password
        self._descriptor_bytes: bytes = descriptor_bytes
        self._request_auth_token()


    def post_descriptor(self) -> None:
        url = self._wfm_base_url + '/rest/components/registerUnmanaged'
        print('Registering component by posting descriptor to', url)
        with execute_http_request_with_retry(url, self._create_post_descriptor_request):
            # We don't need to do anything with the response.
            pass

    def _create_post_descriptor_request(self, url: str) -> urllib.request.Request:
        if time.time() > self._reuse_token_until:
            self._request_auth_token()
        headers = {
            'Authorization': f'Bearer {self._token}',
            'Content-Type': 'application/json'
        }
        return urllib.request.Request(url, self._descriptor_bytes, headers)


    @staticmethod
    def _request_token_url(oidc_issuer_uri: str) -> str:
        config_url = oidc_issuer_uri + '/.well-known/openid-configuration'
        print('Getting OIDC configuration metadata from', config_url)
        with execute_http_request_with_retry(config_url, urllib.request.Request) as resp:
            return json.load(resp)['token_endpoint']


    def _request_auth_token(self) -> None:
        headers = create_basic_auth_header(self._wfm_user, self._wfm_password)

        def create_request(url):
            # Update token url in case there was a redirect.
            self._token_url = url
            return urllib.request.Request(url, b'grant_type=client_credentials', headers)

        print(f'Requesting token from {self._token_url}')
        with execute_http_request_with_retry(self._token_url, create_request) as resp:
            resp_content = json.load(resp)

        self._token = resp_content['access_token']
        expires_in = resp_content['expires_in']
        self._reuse_token_until = time.time() + expires_in
        if expires_in > 60:
            self._reuse_token_until -= 60
        print(f'Received token that expires in {expires_in} seconds.')


def create_basic_auth_header(user: str, password: str) -> Dict[str, str]:
    auth_info_bytes = (user + ':' + password).encode()
    base64_auth_info = base64.b64encode(auth_info_bytes).decode()
    return {'Authorization': f'Basic {base64_auth_info}'}
