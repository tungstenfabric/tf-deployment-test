import testtools
from my_fixtures import HostFixture
import os

class BaseTestCase(testtools.TestCase):
    def setUp(self):
        self.hostFixture = self.useFixture(HostFixture())
        self.workspace_path = os.getenv('WORKSPACE')
        super(BaseTestCase, self).setUp()

    def check_cmd_on_host(self,cmd):
        (exec_res, stdout, stderr) = self.hostFixture.execOnHost(cmd)
        for line in stdout.readlines():
            self.logger.info("%s " % line)
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        self.assertFalse(exec_res)

    def run_bash_test_on_host(
            self, bash_file_name,
            bash_local_test_dir = None,
            bash_remote_test_dir = "/tmp/tf-deployment-test"):
        if not bash_local_test_dir:
            bash_local_test_dir = os.path.join(self.workspace_path, "bash_tests")
        self.check_cmd_on_host( "mkdir -p " + bash_remote_test_dir)
        local_path = os.path.join(bash_local_test_dir, bash_file_name)
        remote_path = os.path.join(bash_remote_test_dir, bash_file_name)
        self.hostFixture.copyLocalFileToRemote(local_path, remote_path)
        self.check_cmd_on_host(remote_path)