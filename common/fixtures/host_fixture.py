import fixtures
import io
import os
import paramiko
import select
import sys
from subprocess import check_call


class HostFixture(fixtures.Fixture):

    SSH_OPTS = " ".join([
        "-i /root/.ssh/id_rsa",
        "-o UserKnownHostsFile=/dev/null",
        "-o StrictHostKeyChecking=no",
        "-o PasswordAuthentication=no"
    ])

    def __init__(self, ssh_host, ssh_user, logger):
        self.ssh_user = ssh_user
        self.ssh_host = ssh_host
        self.logger = logger

    def _rsync_data(self, path):
        if not self.ssh_user or not self.ssh_host:
            tmsg = "ERROR: ssh credentials are invalid: host=%s user=%s"
            raise Exception(tmsg % (self.ssh_host, self.ssh_user))
        check_call(["rsync", "-Pav", "-e", "ssh " + self.SSH_OPTS,
                    path, f"{self.ssh_user}@{self.ssh_host}:/tmp/"])

    def _setUp(self):
        self._rsync_data("/tf-deployment-test")
        self._rsync_data("/input/test.env")

    def _get_connection(self):
        self.logger.debug("Open ssh connection host=%s user=%s" %
                          (self.ssh_host, self.ssh_user))
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        # NOTE: we assume that key is stored in default place - /root/.ssh/id_rsa
        # TODO: add retries https://github.com/openstack/tempest/blob/master/tempest/lib/common/ssh.py
        ssh.connect(self.ssh_host, username=self.ssh_user, timeout=5)
        return ssh

    def get_remote_path(self, local_file_path):
        return os.path.join("/tmp/tf-deployment-test", local_file_path)

    def exec_command(self, command, fout=None, ferr=None, timeout=5):
        with self._get_connection() as ssh:
            self.logger.debug("Start command over ssh command='%s'" % (command))
            stdin, stdout, stderr = ssh.exec_command(command)
            self.logger.debug("Command started, waiting result...")
            # get the shared channel for stdout/stderr/stdin
            with stdout.channel as channel:
                # we do not need stdin.
                stdin.close()
                # indicate that we're not going to write to that channel anymore
                channel.shutdown_write()
                _fout = fout if fout else sys.stdout
                _ferr = ferr if ferr else sys.stderr
                _fout.buffer.write(channel.recv(len(channel.in_buffer)))
                _fout.flush()
                while not channel.closed or \
                        channel.recv_ready() or \
                        channel.recv_stderr_ready():
                    got_chunk = False
                    readq, _, _ = select.select([channel], [], [], timeout)
                    for c in readq:
                        if c.recv_ready():
                            _fout.buffer.write(channel.recv(len(c.in_buffer)))
                            _fout.flush()
                            got_chunk = True
                        if c.recv_stderr_ready():
                            _ferr.buffer.write(channel.recv_stderr(len(c.in_stderr_buffer)))
                            _ferr.flush()
                            got_chunk = True
                    # if new data comes or data were read, try read more
                    if got_chunk or channel.recv_stderr_ready() or channel.recv_ready():
                        continue
                    if channel.exit_status_ready():
                        # no more data and process ended
                        break
                # indicate that we're not going to read from this channel anymore
                channel.shutdown_read()
                stdout.close()
                stderr.close()
                res = channel.recv_exit_status()
            self.logger.debug("Command finished, res=%s" % (res))
            if res:
                msg = f'ERROR: SSH Command "{command}" failed with exit code {res}'
                raise Exception(msg)

    def exec_command_result(self, command, timeout=5):

        class SimpleBuffer(io.BytesIO):
            @property
            def buffer(self):
                return self

        with SimpleBuffer() as fout:
            self.exec_command(command, fout=fout, timeout=timeout)
            return fout.getvalue().decode('utf-8')

    def copy_local_file_to_remote(self, local_path, remote_path):
        with self._get_connection() as ssh:
            with ssh.open_sftp() as ftp_client:
                ftp_client.put(local_path, remote_path)
