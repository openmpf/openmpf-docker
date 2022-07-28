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

from __future__ import annotations

import contextlib
import errno
import logging
import multiprocessing
import os
import selectors
import signal
import socket
import sys
from typing import Iterable, List, Optional

import mpf_cli_executor_process
import mpf_cli_runner_util as util

log = logging.getLogger('org.mitre.mpf.cli')


def main():
    fix_sig_term()
    mpf_cli_executor_process.LogConfig.configure_server_logging()
    log.info(f'server pid = {os.getpid()}')
    with ComponentServer() as server:
        server.serve()


def start_from_client(client_to_server_sock: socket.socket) -> None:
    print('No existing server. Starting new one...', file=sys.stderr)
    try:
        # Construct server before forking to make sure it is listening before the client attempts
        # to connect.
        server = ComponentServer(util.get_idle_timeout())
    except OSError as e:
        if e.errno == errno.EADDRINUSE:
            print('Another server was started at the same time. Using existing server.',
                  file=sys.stderr)
            return
        else:
            raise

    with server:
        fork_ret_val = os.fork()
        is_client_process = fork_ret_val > 0
        if is_client_process:
            print(f'Server started with pid {fork_ret_val}', file=sys.stderr)
            return

        client_to_server_sock.close()
        with open(os.devnull, 'r') as dev_null, open(get_log_file_name(), 'w') as log_file:
            os.dup2(dev_null.fileno(), 0)
            os.dup2(log_file.fileno(), 1)
            os.dup2(log_file.fileno(), 2)
        mpf_cli_executor_process.LogConfig.configure_server_logging()
        log.info(f'server pid = {os.getpid()}')
        server.serve()
    sys.exit()


def get_log_file_name() -> str:
    if log_file := os.getenv('COMPONENT_SERVER_LOG'):
        return log_file
    else:
        return f'component-server-{os.getpid()}.log'


def fix_sig_term() -> None:
    """
    Explicitly handle SIGTERM when running as pid 1.
    This is required because Linux disables the default signal handlers for pid 1.
    """
    if os.getpid() == 1:
        # Linux disables default signal handlers for pid 1.
        signal.signal(signal.SIGTERM, lambda sig_num, frame: sys.exit(128 + sig_num))


class ComponentServer(contextlib.AbstractContextManager):
    """
    ComponentServer listens for new client connections and manages a pool of processes that run
    execute jobs. When a client connection is accepted, that socket's file descriptor is sent
    to an executor. ComponentServer does not read or write to the client socket, that is handled
    by an executor process.
    """
    def __init__(self, server_idle_timeout: Optional[int] = None):
        with contextlib.ExitStack() as exit_stack:
            self._server_sock = exit_stack.enter_context(socket.socket(socket.AF_UNIX))
            self._server_sock.bind(util.SOCKET_ADDRESS)
            self._server_sock.listen(1024)

            self._selector = exit_stack.enter_context(selectors.DefaultSelector())
            self._selector.register(self._server_sock, selectors.EVENT_READ)

            self._executor_processes: List[ExecutorProcessManager] = []
            self._stats = Stats()
            self._idle_timeout = server_idle_timeout

            self._exit_stack = exit_stack.pop_all()


    def __exit__(self, *exc_details):
        self._exit_stack.__exit__(*exc_details)


    def serve(self) -> None:
        try:
            while True:
                client_sock = self._wait_for_accept()
                if client_sock is None:
                    return
                with client_sock:
                    self._handle_single_request(client_sock)
        except BaseException:
            log.debug(self._stats)
            for proc in self._executor_processes:
                proc.terminate()
            raise


    def _handle_single_request(self, client_sock: socket.socket) -> None:
        self._stats.on_new_job_received()
        while True:
            try:
                self._find_idle_process(client_sock).submit_job(client_sock)
                return
            except TryAgain:
                log.info('Resubmitting job because selected child process exited as the job was '
                         'submitted.')


    def _find_idle_process(self, client_sock: socket.socket) -> ExecutorProcessManager:
        for process in self._executor_processes:
            if process.is_alive() and process.is_idle():
                log.info('Re-using existing process for job.')
                return process

        log.info('Creating new executor process')
        new_process = ExecutorProcessManager(client_sock, self._server_sock)
        self._executor_processes.append(new_process)
        self._selector.register(new_process.get_sentinel(), selectors.EVENT_READ)
        self._stats.on_process_started()
        return new_process


    def _remove_dead_processes(self) -> None:
        still_alive = []
        for process in self._executor_processes:
            if process.is_alive():
                still_alive.append(process)
            else:
                self._selector.unregister(process.get_sentinel())
                exit_code = process.cleanup()
                self._stats.on_process_exited(exit_code)

        num_removed = len(self._executor_processes) - len(still_alive)
        if num_removed != 0:
            log.info(f'Reaping {num_removed} processes.')
        self._executor_processes = still_alive


    # Returns None when the server should exit due to idle.
    def _wait_for_accept(self) -> Optional[socket.socket]:
        # Will loop when unblocked because a child process exited.
        while True:
            self._remove_dead_processes()
            log.debug(self._stats)
            can_exit_due_to_idle = (self._idle_timeout is not None
                                    and len(self._executor_processes) == 0 and os.getpid() != 1)
            if can_exit_due_to_idle:
                return self._wait_for_accept_with_timeout()

            ready_list = self._selector.select()
            for key, _ in ready_list:
                if key.fileobj is self._server_sock:
                    # ready_list may also contain exited processes, but we want to prioritize
                    # starting the new job.
                    return self._server_sock.accept()[0]


    # Returns None when the server should exit due to idle.
    def _wait_for_accept_with_timeout(self) -> Optional[socket.socket]:
        ready_list = self._selector.select(self._idle_timeout)
        if ready_list:
            return self._server_sock.accept()[0]
        else:
            log.info('Exiting due to idle')
            log.debug(self._stats)
            return None


class Stats:
    def __init__(self):
        self.job_count = 0
        self.max_active = 0
        self.processes_started = 0
        self.processes_exited = 0
        self.process_errors = 0

    def on_new_job_received(self) -> None:
        self.job_count += 1

    def on_process_started(self) -> None:
        self.processes_started += 1
        self.max_active = max(self.max_active, len(multiprocessing.active_children()))

    def on_process_exited(self, exit_code: int) -> None:
        self.processes_exited += 1
        if exit_code != 0:
            self.process_errors += 1

    def __str__(self):
        return f'Jobs submitted = {self.job_count}, max active processes = {self.max_active}, ' \
               f'processes started = {self.processes_started}, exited = {self.processes_exited}, ' \
               f'errors = {self.process_errors}'


class TryAgain(Exception):
    ...


class ExecutorProcessManager:
    """
    Starts a component executor process. Sends new jobs to the executor process using a Unix
    socket. The protocol is as follows:
    1. Executor is informed of a new job when it receives a message containing one byte of regular
       data and ancillary data containing a single file descriptor. The one byte of regular data
       is ignored. It is sent because a message can't contain only ancillary data. The file
       descriptor is the client socket returned from socket.accept.
    2. Executor interacts with the socket to get the job information, run the job, then sends the
       results to the client socket.
    3. Executor sends a 1 byte message to ComponentServer to indicate it finished the job and is
       now idle.
    """
    def __init__(self, client_sock: socket.socket, listen_sock: socket.socket):
        self._to_child, from_parent = socket.socketpair(socket.AF_UNIX)
        with from_parent, contextlib.ExitStack() as exit_stack:
            exit_stack.enter_context(self._to_child)
            # The executor process will inherit the parent's file descriptors, even the ones it
            # does not need.
            close_in_child = (
                # Executor process doesn't listen for new connections.
                listen_sock,
                # If we don't close this, the executor will keep open the socket to the client
                # that was being processed when it was initially created.
                client_sock,
                # This is the server process's side of the socket pair.
                self._to_child
            )
            self._process = multiprocessing.Process(
                target=self._run_executor_in_subprocess,
                args=(from_parent, close_in_child),
                daemon=True)
            self._process.start()
            exit_stack.callback(self._process.close)
            self._pid = self._process.pid
            self._is_idle = True
            self._broken_pipe = False

            self._selector = exit_stack.enter_context(selectors.DefaultSelector())
            self._selector.register(self._to_child, selectors.EVENT_READ)

            self._exit_stack = exit_stack.pop_all()


    @staticmethod
    def _run_executor_in_subprocess(from_parent_socket: socket.socket,
                                    sockets_to_close: Iterable[socket.socket]) -> None:
        for s in sockets_to_close:
            s.close()
        with mpf_cli_executor_process.ExecutorProcess(from_parent_socket) as executor:
            executor.run_jobs()


    def submit_job(self, client_sock: socket.socket) -> None:
        self._is_idle = False
        try:
            util.send_fds(self._to_child, client_sock.fileno())
        except BrokenPipeError as e:
            self._broken_pipe = True
            raise TryAgain() from e


    def is_idle(self) -> bool:
        if self._is_idle:
            return True
        job_complete = len(self._selector.select(0)) > 0
        if job_complete:
            self._to_child.recv(1)
            self._is_idle = True
        return self._is_idle


    def is_alive(self) -> bool:
        return self._process.is_alive() and not self._broken_pipe

    def cleanup(self) -> int:
        self._process.join(0.5)
        if self._process.is_alive():
            self._process.terminate()
        exit_code = self._process.exitcode
        log.info(f'Process {self._pid} exited wit exit code {exit_code}')
        self._exit_stack.close()
        return exit_code

    def get_sentinel(self) -> int:
        return self._process.sentinel

    def terminate(self) -> None:
        self._process.terminate()


if __name__ == '__main__':
    main()
