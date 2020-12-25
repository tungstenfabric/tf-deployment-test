import fixtures
import logging
import io
import os
import paramiko
import select
import sys
from subprocess import check_call


class HostFixture(fixtures.Fixture):

    SSH_OPTS = "-i /root/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

    def __init__(self, ssh_host=None, ssh_user=None):
        self.logger = logging.getLogger(__name__ + '.HostFixture')
        self.ssh_user = ssh_user or os.getenv("SSH_USER")
        self.ssh_host = ssh_host or os.getenv("SSH_HOST")

    def _setUp(self):
        if not self.ssh_user or not self.ssh_host:
            raise Exception(f"ERROR: credentials are invalid: ssh_host={self.ssh_host} ssh_user={self.ssh_user}")
        dest_path = f"{self.ssh_user}@{self.ssh_host}:/tmp/"
        rsync_cmd = ["rsync", "-Pav", "-e", "ssh " + self.SSH_OPTS, "/tf-deployment-test", dest_path]
        check_call(rsync_cmd)
        rsync_cmd = ["rsync", "-Pav", "-e", "ssh " + self.SSH_OPTS, "/input/test.env", dest_path]
        check_call(rsync_cmd)

    def _get_connection(self):
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        # NOTE: we assume that key is stored in default place - /root/.ssh/id_rsa
        # TODO: add retries https://github.com/openstack/tempest/blob/master/tempest/lib/common/ssh.py
        ssh.connect(self.ssh_host, username=self.ssh_user, timeout=5)
        return ssh

    def get_remote_path(self, local_file_path):
        return os.path.join("/tmp/tf-deployment-test", local_file_path)


    def exec_command(self, command, fout=None, ferr=None, timeout=5):
        ssh = self._get_connection()
        stdin, stdout, stderr = ssh.exec_command(command) 
        # get the shared channel for stdout/stderr/stdin
        channel = stdout.channel
        # we do not need stdin.
        stdin.close() 
        # indicate that we're not going to write to that channel anymore
        channel.shutdown_write()
        _fout = fout if fout else sys.stdout
        _ferr = ferr if ferr else sys.stderr
        _fout.write(channel.recv(len(channel.in_buffer)))
        while not channel.closed or channel.recv_ready() or channel.recv_stderr_ready():
            got_chunk = False
            readq, _, _ = select.select([channel], [], [], timeout)
            for c in readq:
                if c.recv_ready(): 
                    _fout.write(channel.recv(len(c.in_buffer)))
                    got_chunk = True
                if c.recv_stderr_ready():   
                    _ferr.write(channel.recv_stderr(len(c.in_stderr_buffer)))
                    got_chunk = True
            if not got_chunk and \
                channel.exit_status_ready() and \
                not channel.recv_stderr_ready() and \
                not channel.recv_ready():
                # indicate that we're not going to read from this channel anymore
                channel.shutdown_read() 
                channel.close()
                break

        stdout.close()
        stderr.close()
        res = channel.recv_exit_status()
        ssh.close()
        if res:
            raise Exception(f'SSH Command "{command}" failed with exit code {res}.')

    def exec_command_result(self, command, timeout=5):
        with io.BytesIO() as fout:
            exec_command(command, fout=fout, timeout=timeout)
            return fout.getvalue()


    def copy_local_file_to_remote(self, local_path, remote_path):
        ssh = self._get_connection()
        with ssh.open_sftp() as ftp_client:
            ftp_client.put(local_path, remote_path)
        ssh.close()
