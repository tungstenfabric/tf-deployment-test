import os
import time
import testtools

from common.fixtures.host_fixture import HostFixture


class DeploymentTestCase(testtools.TestCase):

    def run_test_remotely(self, local_file_path):
        host_fixture = self.useFixture(HostFixture())
        remote_path = host_fixture.get_remote_path(local_file_path)
        host_fixture.exec_command(remote_path)

    def get_controller_nodes(self):
        # list can be space or comma separated
        return os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")

    def restart_containers(self, name_filter=""):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        controller_nodes = self.get_controller_nodes()
        for node in controller_nodes:
            host_fixture = self.useFixture(HostFixture(ssh_host=node))
            cmd = f'sudo docker ps -q -f name={name_filter}'
            result = host_fixture.exec_command_result(cmd)
            cmd = 'sudo docker restart ' + ' '.join(result.split())
            host_fixture.exec_command(cmd)

        # TODO: use correct wait. think about usefulness of this wait
        time.sleep(10)
