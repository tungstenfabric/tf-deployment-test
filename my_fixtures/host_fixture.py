import fixtures
import paramiko
from paramiko.ssh_exception import SSHException
import os
import sys
import stat
from testtools.content import text_content, attach_file
import logging

logging.basicConfig(level=logging.INFO)


class HostFixture(fixtures.Fixture):

    def __init__(self, hostname=None, username=None, key_filename=None, timeout=5):
        self.logger = logging.getLogger(__name__ + '.HostFixture_init')
        host_user = username or os.getenv("TF_HOST_USER")
        host_key = key_filename or os.getenv("TF_SSH_KEY")
        self.host = hostname or os.getenv("TF_HOST_ADDR")
        self.logger.info(f"init ssh connection with {self.host}")
        ssh_file = os.path.expanduser('pk.key')
        with open(ssh_file, 'w') as fd:
            fd.write(host_key)
        os.chmod(ssh_file, stat.S_IRWXU)
        rsync_cmd = "rsync -Pav -e \"ssh -i %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\" /tf-deployment-test %s@%s:/tmp/" % (
        ssh_file, host_user, self.host)
        code = os.system(rsync_cmd)
        if (code):
            raise Exception("ERROR: rsync tests to host fails with code %s " % code)
        if (not host_user or not host_key or not self.host):
            raise Exception("ERROR: Need to pass host credentials to run the tests")
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self._client.connect(hostname=self.host, username=host_user, key_filename=ssh_file, timeout=timeout)

    def exec_on_host(self, command):
        if(not self._client):
            raise Exception("ERROR: connection has not been set up yet")
        chan = self._client.get_transport().open_session()
        stdout = chan.makefile()
        stderr = chan.makefile_stderr()
        try:
            chan.exec_command(command)
            exec_res = chan.recv_exit_status()
        except SSHException:
            exec_res = 1
        return (exec_res, stdout, stderr)

    def check_cmd_on_node_by_ssh(self, cmd):
        (exec_res, stdout, stderr) = self.exec_on_host(cmd)
        output_text = ""
        self.logger.info("-" * 20)
        self.logger.info(f"vipolnim na {self.host} po ssh: {cmd}")
        for line in stdout.readlines():
            # self.logger.info("%s " % line)
            output_text += f"{line}\n"
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        self.logger.info(f"exec_res: {exec_res}")
        self.logger.info(f"return ssh:\n{output_text}".strip())
        self.logger.info("=" * 20)
        return output_text

    def copy_local_file_to_remote(self,localPath, remotePath):
        if(not self._client):
            raise Exception("ERROR: connection has not been set up yet")
        with self._client.open_sftp() as ftp_client:
            ftp_client.put(localPath, remotePath)
