#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2021 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2021 The MITRE Corporation                                      #
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

from __future__ import annotations

import argparse
import array
import contextlib
from enum import EnumMeta
import glob
import json
import logging
import operator
import os
import pickle
import selectors
import socket
import sys
import threading
from typing import Any, ContextManager, Dict, List, Mapping, NoReturn, Optional, TextIO, Tuple, \
    Union

import mpf_cli_job_runner
import mpf_cli_runner_util as util

log = logging.getLogger('org.mitre.mpf.cli')


class ExecutorProcess(contextlib.AbstractContextManager):
    """
    Waits for new jobs from the component server and starts them. Also manages resources that
    should persist between jobs, like the component instance and the connection the component
    server.
    """
    def __init__(self, parent_socket: socket.socket):
        log.info(f'Executor process started with pid {os.getpid()}.')
        with contextlib.ExitStack() as exit_stack:
            self._from_parent_socket = exit_stack.enter_context(parent_socket)

            self._selector = exit_stack.enter_context(selectors.DefaultSelector())
            self._selector.register(parent_socket, selectors.EVENT_READ)

            self._component = None
            self._descriptor = None
            self._job_sync = JobSync()
            self._idle_timeout = util.get_idle_timeout()
            self._exit_stack = exit_stack.pop_all()


    def run_jobs(self) -> None:
        runner_exception = None

        def _run_jobs_in_thread():
            nonlocal runner_exception
            try:
                self._run_jobs()
            except BaseException as thread_exception:
                runner_exception = thread_exception
                raise

        # Watching for close was chosen to run on the main thread and running the job is done on
        # another thread because only the main thread can handle signals. If a C++ component is
        # running on the main thread, the program wouldn't respond to signals until it finished the
        # job.
        runner_thread = threading.Thread(target=_run_jobs_in_thread, daemon=True)
        runner_thread.start()

        try:
            self._check_close(self._job_sync)
        except threading.BrokenBarrierError:
            # Runner thread closed self._job_sync. If it was due to an error, the exception will be
            # stored in the runner_exception variable.
            pass
        except JobAbortedException:
            sys.exit(3)
        except BaseException as e:
            runner_thread.join()
            if runner_exception is not None:
                # Prefer reporting runner thread's exception over the watcher thread's exception.
                raise runner_exception
            else:
                raise e

        runner_thread.join()
        if runner_exception is not None:
            raise runner_exception


    @staticmethod
    def _check_close(job_sync: JobSync) -> NoReturn:
        with contextlib.closing(job_sync):
            while True:
                with job_sync.begin_watch_job_abort() as client_sock:
                    # Will unblock if either we close the connection because the job is done or if
                    # the client closed the connection before the job was completed.
                    client_sock.recv(1)
                    if job_sync.is_active():
                        log.warning('Client closed connection before job could complete.')
                        raise JobAbortedException()


    def _run_jobs(self) -> None:
        with contextlib.closing(self._job_sync):
            while True:
                ready_list = self._selector.select(self._idle_timeout)
                job_received = len(ready_list) > 0
                if job_received:
                    self._run_job()
                else:
                    log.info('Executor process exiting due to idle timeout.')
                    return


    def _run_job(self) -> None:
        with self._recv_client_socket() as client_sock, \
                JobRequest(client_sock) as job_request, \
                self._job_sync.begin_process_job(client_sock):

            self._init_component(job_request.cmd_line_args)
            with mpf_cli_job_runner.JobRunner(
                    job_request.cmd_line_args, job_request.env_props, job_request.stdin,
                    self._component, self._descriptor) as runner:
                runner.run_job()
        self._from_parent_socket.send(b'\x00')


    @contextlib.contextmanager
    def _recv_client_socket(self) -> ContextManager[socket.socket]:
        client_sock_fd = recv_fds(self._from_parent_socket, 1)[0]
        try:
            client_sock = socket.socket(fileno=client_sock_fd)
        except Exception:
            os.close(client_sock_fd)
            raise

        with client_sock:
            try:
                yield client_sock
                client_sock.send(b'\x00')
            except BaseException:
                # Send response in a context manager so that once a job has been received, we are
                # guaranteed to respond to client preventing it from blocking indefinitely while
                # waiting for a response.
                # It also helps to ensure that responding to the client is very last thing that
                # can be done with the client socket.
                client_sock.send(b'\x01')
                raise


    def _init_component(self, cmd_args) -> None:
        if self._component:
            return

        self._descriptor = self._load_descriptor(cmd_args.descriptor_file)
        lang = self._descriptor['sourceLanguage'].lower()
        if lang == 'c++':
            # Need to conditionally import because the C++ SDK won't be installed in Python
            # component images.
            import mpf_cpp_runner
            self._component = mpf_cpp_runner.CppComponentHandle(self._descriptor)
            self._exit_stack.enter_context(self._component)
        elif lang == 'python':
            # Need to conditionally import because the Python SDK won't be installed in C++
            # component images.
            import mpf_python_runner
            self._component = mpf_python_runner.PythonComponentHandle(self._descriptor)
        else:
            raise NotImplementedError(f'{lang} components are not supported.')


    @classmethod
    def _load_descriptor(cls, descriptor_file: Optional[TextIO]) -> Dict[str, Any]:
        if descriptor_file:
            log.info(f'Loading descriptor from {descriptor_file.name}')
            descriptor = json.load(descriptor_file)
            descriptor_file.close()
            cls._set_env_vars_from_descriptor(descriptor)
            return descriptor

        mpf_home = os.getenv('MPF_HOME', '/opt/mpf')
        glob_pattern = os.path.join(mpf_home, 'plugins/*/descriptor/descriptor.json')
        glob_matches = glob.glob(glob_pattern)

        if len(glob_matches) == 1:
            descriptor_path = glob_matches[0]
            log.info(f'Loading descriptor from {descriptor_path}')
            with open(descriptor_path) as f:
                descriptor = json.load(f)
            cls._set_env_vars_from_descriptor(descriptor)
            return descriptor

        if len(glob_matches) == 0:
            raise RuntimeError(f'Expecting to find a descriptor file at "{glob_pattern}", '
                               'but it was not there.')
        else:
            raise RuntimeError(f'Expected to find one descriptor matching "{glob_pattern}", '
                               f'but the following descriptors were found: {glob_matches}')

    @staticmethod
    def _set_env_vars_from_descriptor(descriptor: Dict[str, Any]) -> None:
        env = os.environ
        for json_env_var in descriptor.get('environmentVariables', ()):
            var_name = json_env_var['name']
            var_value = util.expand_env_vars(json_env_var['value'], env)
            sep = json_env_var.get('sep')

            existing_val = env.get(var_name) if sep else None
            if sep and existing_val:
                env[var_name] = existing_val + sep + var_value
            else:
                env[var_name] = var_value

    def __exit__(self, *exc_details):
        return self._exit_stack.__exit__(*exc_details)



class JobRequest(contextlib.AbstractContextManager):
    """
    Manages and cleans up the resources associated with a job request. Since file descriptors are
    being sent over the socket, they must be closed. They must be closed before replying to the
    client. One reason is that we don't want the client to attempt to access the results before
    they are completely written out and closing a file flushes any buffered content. We also don't
    know if these file descriptors refer to something like a pipe that may not exist after
    responding to the client.

    A job request is sent from the client to the executor process using a Unix socket.
    The request includes four messages:
      1. 1 byte of regular data and ancillary data containing three file descriptors. The byte of
         regular data is ignored. The three file descriptors are the client's standard in,
         standard out, and standard error.
      2. A message containing the client's command line arguments encoded as a pickled list of
         strings.
      3. A message containing the client's working directory encoded as a pickled string.
      4. A message containing the client's environment variables that were used to provide job
         properties encoded as a pickled dictionary with string keys and values.
    The executor will write log messages to the received standard error. It will also interact
    with the client's standard in and standard out if the command line arguments indicate that
    it should.
    After all job related information is written to the client's standard streams, a single
    byte will be written to the client socket. The byte contains the exit code the client should
    use when it exits. A zero byte is written for success and a non-zero for an error. The byte is
    unsigned since Linux exit codes must be positive.
    """
    stdin: TextIO
    cmd_line_args: argparse.Namespace
    env_props: Mapping[str, str]

    def __init__(self, client_sock: socket.socket):
        with contextlib.ExitStack() as exit_stack:
            self.stdin, stdout, stderr = self._get_job_streams(client_sock)
            exit_stack.callback(self.stdin.close)
            exit_stack.callback(stdout.close)
            exit_stack.callback(stderr.close)

            # Make diagnostic message go to the client's standard error.
            exit_stack.enter_context(replace_fd_temp(sys.stdout, stderr))
            exit_stack.enter_context(replace_fd_temp(sys.stderr, stderr))

            with client_sock.makefile('rb') as sf:
                argv: List[str] = pickle.load(sf)
                client_cwd: str = pickle.load(sf)
                self.env_props = pickle.load(sf)

            self.cmd_line_args = ArgumentParser.parse(argv, client_cwd, stdout, stderr)

            # This must be added to the stack last so that during clean up it is called before
            # closing the client's streams.
            exit_stack.enter_context(LogConfig.config_job_logging(stderr, self.cmd_line_args))

            self._exit_stack = exit_stack.pop_all()

    @staticmethod
    def _get_job_streams(client_sock: socket.socket) -> Tuple[TextIO, TextIO, TextIO]:
        stdin_fd, stdout_fd, stderr_fd = recv_fds(client_sock, 3)
        try:
            return os.fdopen(stdin_fd, 'r'), os.fdopen(stdout_fd, 'w'), os.fdopen(stderr_fd, 'w')
        except Exception:
            # When os.fdopen fails, we still need to close the file descriptor. Since there is
            # no file object to call close on, the low level os.close must be used.
            os.close(stdin_fd)
            os.close(stdout_fd)
            os.close(stderr_fd)
            raise

    def __exit__(self, *exc_info):
        return self._exit_stack.__exit__(*exc_info)


class JobSync:
    """
    Manages synchronization between the thread that watches for job cancellation and the thread
    executing the job.
    """
    def __init__(self):
        self._client_socket: Optional[socket.socket] = None
        self._is_job_active = False
        self._begin_job_barrier = threading.Barrier(2)
        self._end_job_barrier = threading.Barrier(2)
        self._lock = threading.Lock()

    @contextlib.contextmanager
    def begin_process_job(self, client_socket) -> ContextManager[None]:
        with self._lock:
            self._client_socket = client_socket
            self._is_job_active = True
        # Inform the watcher thread that a new job is being processed.
        self._begin_job_barrier.wait()

        yield
        with self._lock:
            self._is_job_active = False
            # Call socket.shutdown to unblock the watcher's socket.recv. Normally socket.recv will
            # only unblock when the remote side of the socket is closed.
            # The call to shutdown also must occur after `self._is_job_active = False` so the
            # watcher doesn't think the client prematurely closed the connection.
            self._client_socket.shutdown(socket.SHUT_RD)
        # Wait until the watcher is no longer watching the socket to ensure the watcher is always
        # watching the current job's socket and not one from a previous job.
        self._end_job_barrier.wait()
        with self._lock:
            self._client_socket = None

    @contextlib.contextmanager
    def begin_watch_job_abort(self) -> ContextManager[socket.socket]:
        # Wait until the executor thread gets a new job and begins running it.
        self._begin_job_barrier.wait()
        # Expose the socket to the watcher.
        yield self._client_socket
        # Inform executor that the watcher is no longer using the socket.
        self._end_job_barrier.wait()

    def is_active(self) -> bool:
        with self._lock:
            is_active = self._is_job_active
        return is_active

    def close(self) -> None:
        """
        Used to signal to the other thread that it should exit. It may be done because the process
        is exiting because it has been idle for long enough or if an error occurs.
        """
        self._begin_job_barrier.abort()
        self._end_job_barrier.abort()


class JobAbortedException(Exception):
    ...


# From https://docs.python.org/3/library/socket.html#socket.socket.recvmsg
def recv_fds(sock: socket.socket, max_fds: int) -> List[int]:
    fds = array.array("i")   # Array of ints
    try:
        # At least one byte of regular data needs to be sent with the ancillary data, so the
        # sender will send one byte of regular data.
        # The receiver reads the byte from the socket, then ignores it.
        regular_data_size = 1
        msg, ancillary_data, flags, addr = sock.recvmsg(
            regular_data_size, socket.CMSG_LEN(max_fds * fds.itemsize))
        for cmsg_level, cmsg_type, cmsg_data in ancillary_data:
            if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                # Append data, ignoring any truncated integers at the end.
                fds.frombytes(cmsg_data[:len(cmsg_data) - (len(cmsg_data) % fds.itemsize)])
        return list(fds)
    except Exception:
        for fd in fds:
            os.close(fd)
        raise


@contextlib.contextmanager
def replace_fd_temp(fd_to_replace: TextIO, replacement: TextIO) -> ContextManager[None]:
    fd_to_replace.flush()
    replacement.flush()
    stashed_fd = os.dup(fd_to_replace.fileno())
    try:
        os.dup2(replacement.fileno(), fd_to_replace.fileno())
        yield
    finally:
        if not replacement.closed:
            replacement.flush()
        if not fd_to_replace.closed:
            fd_to_replace.flush()
        os.dup2(stashed_fd, fd_to_replace.fileno())
        os.close(stashed_fd)


class LogConfig:
    FORMAT = '%(levelname)-5s %(process)d [%(filename)s:%(lineno)d] - %(message)s'

    @classmethod
    def configure_server_logging(cls) -> None:
        level = cls._get_level_from_env('DEBUG')
        log.setLevel(level)
        # Create duplicate of stderr since stderr will temporarily change while running a job.
        handler = cls._create_handler(os.fdopen(os.dup(2), 'w'), level)
        log.addHandler(handler)


    @classmethod
    @contextlib.contextmanager
    def config_job_logging(cls, stream: TextIO, cmd_line_args) -> ContextManager[None]:
        if cmd_line_args.verbose == 1:
            level_for_job = 'DEBUG'
        elif cmd_line_args.verbose >= 2:
            level_for_job = 'TRACE'
        else:
            level_for_job = cls._get_level_from_env('INFO')

        prev_log_level_env = os.getenv('LOG_LEVEL')
        with contextlib.ExitStack() as exit_stack:
            # Log4cxxConfig.xml checks the $LOG_LEVEL environment variable
            os.environ['LOG_LEVEL'] = level_for_job
            if prev_log_level_env is None:
                exit_stack.callback(operator.delitem, os.environ, 'LOG_LEVEL')
            else:
                exit_stack.callback(operator.setitem, os.environ, 'LOG_LEVEL', prev_log_level_env)

            prev_level = log.getEffectiveLevel()
            log.setLevel(min(prev_level, cls._get_level_int(level_for_job)))
            exit_stack.callback(log.setLevel, prev_level)

            handler = cls._create_handler(stream, level_for_job)
            log.addHandler(handler)
            exit_stack.callback(log.removeHandler, handler)
            exit_stack.callback(handler.flush)
            try:
                yield
            except BaseException as e:
                # Log exception here because it is the last chance to send a log message to the
                # client.
                if log.isEnabledFor(logging.DEBUG):
                    log.exception(f'Job failed due to: {e}')
                else:
                    log.error(f'Job failed due to: {e}')


    @classmethod
    def _create_handler(cls, stream: TextIO, level: str) -> logging.StreamHandler:
        handler = logging.StreamHandler(stream)
        handler.setFormatter(logging.Formatter(cls.FORMAT))
        if level == 'TRACE':
            # Python doesn't use TRACE, so we just log everything when TRACE is provided.
            handler.setLevel(logging.DEBUG)
        else:
            handler.setLevel(level)
        return handler


    @classmethod
    def _get_level_from_env(cls, default_level: str) -> str:
        level_name = os.getenv('LOG_LEVEL', default_level).upper()
        if level_name == 'WARNING':
            # Python logging accepts either WARNING or WARN, but Log4CXX requires it be WARN.
            return 'WARN'
        elif level_name == 'CRITICAL':
            # Python logging accepts either CRITICAL or FATAL, but Log4CXX requires it be FATAL.
            return 'FATAL'
        elif level_name not in ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'):
            print(f'Invalid log level of "{level_name}" provided. Log level will be set to DEBUG.')
            return 'DEBUG'
        else:
            return level_name

    @staticmethod
    def _get_level_int(level: Union[int, str]) -> int:
        if isinstance(level, int):
            return level
        else:
            return logging.getLevelName(level)


class ArgumentParser(argparse.ArgumentParser):
    @classmethod
    def parse(cls, argv: List[str], client_cwd: str, client_std_out: TextIO, job_stderr: TextIO):
        parser = cls(argv[0], client_cwd, client_std_out, job_stderr)
        args = parser.parse_args(argv[1:])
        if args.media_type is None and args.media_path == '-':
            parser.error('When reading from standard in --media-type/-t must be provided.')
        return args


    def __init__(self, exe_name: str, client_cwd: str, client_std_out: TextIO, job_stderr: TextIO):
        super().__init__(prog=exe_name)
        self._job_stderr = job_stderr

        self.add_argument('media_path', type=lambda p: self.get_path(p, client_cwd),
                          help='Path to media to process. To read from standard in use "-"')
        self.add_argument(
            '--media-type', '-t', enum=util.MediaType, action=self.ParseEnumAction,
            help='Specify type of media. Required when reading media from standard in. When not '
                 'reading from standard in, the file extension will be used to guess the media type.')

        self.add_argument(
            '--job-prop', '-P', action=self.ParsePropsAction, dest='job_props',
            metavar='<prop_name>=<value>',
            help='Set a job property for the job. The argument should be the name of the '
                 'job property and its value separated by an "=" (e.g. "-P ROTATION=90"). '
                 'This flag can be specified multiple times to set multiple job properties.')

        self.add_argument(
            '--media-metadata', '-M', action=self.ParsePropsAction,
            metavar='<metadata_name>=<value>',
            help='Set a media metadata value. The argument should be the name of the metadata '
                 'field and its value separated by an "=" (e.g. "-M FPS=29.97"). '
                 'This flag can be specified multiple times to set multiple metadata fields.')

        self.add_argument(
            '--begin', '-b', type=int, default=0,
            help='For videos, the first frame number (0-based index) of the video that should be '
                 'processed. For audio, the time (0-based index, in milliseconds) to begin '
                 'processing the audio file.'
        )
        self.add_argument(
            '--end', '-e', type=int, default=-1,
            help='For videos, the last frame number (0-based index) of the video that should be '
                 'processed. For audio, the time (0-based index, in milliseconds) to stop '
                 'processing the audio file.')

        self.add_argument(
            '--daemon', '-d', action='store_true',
            help='Start up and sleep forever. This can be used to keep the Docker container alive '
                 'so that jobs can be started with `docker exec <container-id> runner ...` .')

        self.add_argument('--pretty', '-p', action='store_true', help='Pretty print JSON output.')

        self.add_argument('--brief', action='store_true', help='Only output tracks.')

        self.add_argument(
            '--output', '-o', type=self.FileTypeWithCustomDirectory(client_cwd, mode='w'),
            default=client_std_out,
            help='The path where the JSON output should written. '
                 'When omitted, JSON output is written to standard out.')

        self.add_argument(
            '--descriptor', type=self.FileTypeWithCustomDirectory(client_cwd),
            dest='descriptor_file',
            help='Specifies which descriptor to use when multiple descriptors are present. '
                 'Usually only needed when running outside of docker.')

        self.add_argument(
            '--verbose', '-v', action='count', default=0,
            help='When provided once, set the log level to DEBUG. '
                 'When provided twice (e.g. "-vv"), set the log level to TRACE')


    def print_help(self, file=None) -> None:
        super().print_help(file or self._job_stderr)


    class ParseEnumAction(argparse.Action):
        def __init__(self, enum: EnumMeta, **kwargs):
            kwargs['choices'] = [e.name.lower() for e in enum]
            super().__init__(**kwargs)
            self._enum = enum

        def __call__(self, parser, namespace, value, option_string=None):
            enum_element = self._enum[value.upper()]
            setattr(namespace, self.dest, enum_element)


    class ParsePropsAction(argparse.Action):
        def __init__(self, **kwargs):
            if 'default' not in kwargs:
                kwargs['default'] = {}
            super().__init__(**kwargs)

        def __call__(self, parser, namespace, value, option_string=None):
            existing_props = getattr(namespace, self.dest)
            prop_key, prop_val = value.split('=', 1)
            existing_props[prop_key] = prop_val


    class FileTypeWithCustomDirectory(argparse.FileType):
        def __init__(self, cwd, **kwargs):
            super().__init__(**kwargs)
            self.__cwd = cwd
            self.__mode = kwargs.get('mode', 'r')

        def __call__(self, path):
            return super().__call__(ArgumentParser.get_path(path, self.__cwd, self.__mode))


    @staticmethod
    def get_path(path: str, client_cwd: str, mode: str = 'r') -> str:
        if path == '-':
            return path

        # If path is an absolute path, join does nothing.
        client_path = os.path.join(client_cwd, path)
        if mode == 'r':
            if os.path.exists(client_path) or not os.path.exists(path):
                return client_path
            else:
                return path
        else:
            client_dir_name = os.path.dirname(client_path)
            provided_dir_name = os.path.dirname(path)
            if os.path.isdir(client_dir_name) or not os.path.isdir(provided_dir_name):
                return client_path
            else:
                return path
