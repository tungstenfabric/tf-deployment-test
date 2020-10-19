import testtools
from my_fixtures import HostFixture
import os

class BaseTestCase(testtools.TestCase):
    def setUp(self):
        self.host_fixture = self.useFixture(HostFixture())
        self.workspace_path = os.getenv('WORKSPACE')
         self.host_fixture.copy_local_file_to_remote(self.workspace_path,"/tmp/tf-deploymant-test")
        super(BaseTestCase, self).setUp()

    def check_cmd_on_host(self,cmd):
        (exec_res, stdout, stderr) = self.host_fixture.exec_on_host(cmd)
        for line in stdout.readlines():
            self.logger.info("%s " % line)
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        self.assertFalse(exec_res)

    def run_bash_test_on_host(
            self, bash_file_name):
        remote_path = os.path.join("/tmp/tf-deployment-test", bash_file_name)
        self.check_cmd_on_host(remote_path)