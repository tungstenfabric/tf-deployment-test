import os
import time
import datetime
import testtools

from common.fixtures.host_fixture import HostFixture


class DeploymentTestCase(testtools.TestCase):
    def setUp(self):
        self.workspace_path = os.getenv('WORKSPACE')
        super(DeploymentTestCase, self).setUp()

    def check_cmd_on_host(self, cmd):
        host_fixture = self.useFixture(HostFixture())
        (exec_res, stdout, stderr) = host_fixture.exec_on_host(cmd)
        for line in stdout.readlines():
            self.logger.info("%s " % line)
        for line in stderr.readlines():
            self.logger.info("bash.stderr: %s " % line)
        # self.assertFalse(exec_res)

    def run_test_remotely(self, bash_file_name):
        remote_path = os.path.join("/tmp/tf-deployment-test", bash_file_name)
        self.check_cmd_on_host(remote_path)

    @staticmethod
    def get_controller_nodes():
        # list can be space or comma separated
        return os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")

    # TODO: rename this!
    # TODO: move this out of base test class
    def restart_containers_without_our_container_by_name(self, cont_name):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        controller_nodes = self.get_controller_nodes()
        for node in controller_nodes:
            host_fixture = self.useFixture(HostFixture(hostname=node))
            test_container_id = host_fixture.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}').strip()
            if not test_container_id:
                reboot_command = "sudo docker restart $(sudo docker ps -q) &>/dev/null"
            else:
                self.logger.info(f'on node {node}: our_container_id = _{test_container_id}_')
                reboot_command = f"sudo docker restart $(sudo docker ps -q | grep -v {test_container_id}) &>/dev/null"
            self.logger.info(f'Begin restarting containers on node {node} in {datetime.datetime.now()}')
            host_fixture.check_cmd_on_node_by_ssh(reboot_command)
            # TODO: use correct wait. think about usefulness of this wait
            time.sleep(60)
            self.logger.info(f'Finished restart on node {node} in {datetime.datetime.now()}')
