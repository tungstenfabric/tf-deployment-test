import os
import logging
import fixtures
import paramiko
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
        rsync_cmd = "rsync -Pav -e \"ssh %s\" /tf-deployment-test %s@%s:/tmp/" % (self.SSH_OPTS, self.ssh_user, self.ssh_host)
        check_call(rsync_cmd, shell=True)
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        # NOTE: we assume that key is stored in default place - /root/.ssh/id_rsa
        self._client.connect(self.ssh_host, username=self.ssh_user, timeout=5)
        self.addCleanup(self._client.close)

    def get_remote_path(self, local_file_path):
        return os.path.join("/tmp/tf-deployment-test", local_file_path)

    def exec(self, command):
        if not self._client:
            raise Exception("ERROR: connection has not been set up yet")
        chan = self._client.get_transport().open_session()
        stdout = chan.makefile()
        stderr = chan.makefile_stderr()
        chan.exec_command(command)
        res = chan.recv_exit_status()
        if res:
            raise Exception(f'SSH Command failed with exit code {res}.\nCommand:\n{command}\n\nstdout:\n{stdout}\n\nstderr:\n{stderr}')

        return stdout, stderr

    def copy_local_file_to_remote(self, local_path, remote_path):
        if not self._client:
            raise Exception("ERROR: connection has not been set up yet")
        with self._client.open_sftp() as ftp_client:
            ftp_client.put(local_path, remote_path)
