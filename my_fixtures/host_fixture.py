import fixtures
import paramiko
from paramiko.ssh_exception import SSHException
import os
import sys
from testtools.content import text_content,attach_file
import logging

class HostFixture(fixtures.Fixture):
    def _setUp(self):
        self.host_user = os.getenv("TF_HOST_USER")
        self.host_key = os.getenv("TF_SSH_KEY")
        self.host = os.getenv("TF_HOST_ADDR")
        ssh_file = os.path.expanduser('pk.key')
        with open(ssh_file, 'w') as fd:
            fd.write(self.host_key)
        os.chmod(ssh_file, stat.S_IRWXU)
        rsync_cmd = "rsync -Pav -e \"ssh -i %s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\" /tf-deployment-test %s@%s:/tmp/" % (ssh_file, self.host_user, self.host)
        code = os.system(rsync_cmd)
        if(code):
            raise Exception("ERROR: rsync tests to host fails with code %s " % code)
        if( not self.host_user or not self.host_key or not self.host):
            raise Exception("ERROR: Need to pass host credentials to run the tests")
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self._client.connect(self.host, username = self.host_user,
                key_filename = ssh_file, timeout = 5)
        self.addCleanup(delattr, self, 'host_user')
        self.addCleanup(delattr, self, 'host_key')
        self.addCleanup(delattr, self, 'host')
        self.addCleanup(self._client.close)

    def exec_on_host(self, command):
        if(not self._client):
            raise Exception("ERROR: connection has not been set up yet")
        exec_res = 0
        chan = self._client.get_transport().open_session()
        stdout = chan.makefile()
        stderr = chan.makefile_stderr()
        try:
            chan.exec_command(command)
            exec_res = chan.recv_exit_status()
        except SSHException:
            exec_res = 1
        return (exec_res, stdout, stderr)

    def copy_local_file_to_remote(self,localPath, remotePath):
        if(not self._client):
            raise Exception("ERROR: connection has not been set up yet")
        with self._client.open_sftp() as ftp_client:
            ftp_client.put(localPath, remotePath)


