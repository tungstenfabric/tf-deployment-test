import testtools
from my_fixtures import HostFixture
import os

class BaseTestCase(testtools.TestCase):
    def setUp(self):
        self.hostFixture = self.useFixture(HostFixture())
        self.workspace_path = os.getenv('WORKSPACE')
        super(BaseTestCase, self).setUp()

    def check_cmd_on_host(self,cmd,logger):
        (exec_res, stdout, stderr) = self.hostFixture.execOnHost(cmd)
        for line in stdout.readlines():
            logger.info("bash.stdout: %s " % line)
        for line in stderr.readlines():
            bash_fails = True
            logger.info("bash.stderr: %s " % line)
        self.assertFalse(exec_res)

    def run_bash_test_on_host(
            self, bash_file_name, logger,
            bash_local_test_dir = os.path.join(
                os.getenv('WORKSPACE'), "bash_tests"),
            bash_remote_test_dir = "/tmp/tf-deployment-test"):
        (exec_res, _, stderr) = self.hostFixture.execOnHost( "mkdir -p " + bash_remote_test_dir )
        if(exec_res != 0):
            raise Exception(stderr)
        local_path = os.path.join(bash_local_test_dir, bash_file_name)
        remote_path = os.path.join(bash_remote_test_dir, bash_file_name)
        self.hostFixture.copyLocalFileToRemote(local_path, remote_path)
        self.check_cmd_on_host("/bin/bash " + remote_path, logger)