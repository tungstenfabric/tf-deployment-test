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
        rsync_cmd = ["rsync", "-Pav", "-e", "ssh " + self.SSH_OPTS, "/tf-deployment-test", f"{self.ssh_user}@{self.ssh_host}:/tmp/"]
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

    def exec_command(self, command):
        ssh = self._get_connection()
        with ssh.get_transport().open_session() as channel:
            channel.fileno()  # Register event pipe
            channel.exec_command(command)
            channel.shutdown_write()

            out_file = channel.makefile('rb', 1024)
            err_file = channel.makefile_stderr('rb', 1024)
            out_data = out_file.read().decode()
            err_data = err_file.read().decode()

            res = channel.recv_exit_status()

        ssh.close()

        if res:
            raise Exception(f'SSH Command failed with exit code {res}.\nCommand:\n{command}\n\nstdout:\n{out_data}\n\nstderr:\n{err_data}')
        return out_data, err_data

    def copy_local_file_to_remote(self, local_path, remote_path):
        ssh = self._get_connection()
        with ssh.open_sftp() as ftp_client:
            ftp_client.put(local_path, remote_path)
        ssh.close()
