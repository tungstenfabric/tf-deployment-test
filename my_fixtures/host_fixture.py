import fixtures
import paramiko
from paramiko.ssh_exception import SSHException
import os
import sys
from testtools.content import text_content,attach_file
import logging

class HostFixture(fixtures.Fixture):
    def _setUp(self):
        self.hostUser = os.getenv("TF_HOST_USER")
        self.hostKey = os.getenv("TF_SSH_KEY")
        self.host = os.getenv("TF_HOST_ADDR")
        with open(os.path.expanduser('pk.key'), 'w') as fd:
            fd.write(self.hostKey)
        if( not self.hostUser or not self.hostKey or not self.host):
            raise Exception("ERROR: Need to pass host credentials to run the tests")
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self._client.connect(self.host, username = self.hostUser,
                key_filename = os.path.expanduser('pk.key'), timeout = 5)
        self.addCleanup(delattr, self, 'hostUser')
        self.addCleanup(delattr, self, 'hostKey')
        self.addCleanup(delattr, self, 'host')
        self.addCleanup(self._client.close)

    def execOnHost(self, command):
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

    def copyLocalFileToRemote(self,localPath, remotePath):
        if(not self._client):
            raise Exception("ERROR: connection has not been set up yet")
        with self._client.open_sftp() as ftp_client:
            ftp_client.put(localPath, remotePath)


