import os
import time
import testtools

from common.fixtures.host_fixture import HostFixture


class DeploymentTestCase(testtools.TestCase):

    def run_test_remotely(self, local_file_path):
        host_fixture = self.useFixture(HostFixture())
        remote_path = host_fixture.get_remote_path(local_file_path)
        return host_fixture.exec_command(remote_path)

    def get_controller_nodes(self):
        # list can be space or comma separated
        return os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")

    def get_agent_nodes(self):
        return os.environ["AGENT_NODES"].replace(",", " ").split(",")

    def restart_containers(self, name_filter=""):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        controller_nodes = self.get_controller_nodes()
        for node in controller_nodes:
            host_fixture = self.useFixture(HostFixture(ssh_host=node))
            cmd = f'sudo docker ps -q -f name={name_filter}'
            stdout, stderr = host_fixture.exec_command(cmd)
            cmd = 'sudo docker restart ' + ' '.join(stdout.split())
            host_fixture.exec_command(cmd)

        # TODO: use correct wait. think about usefulness of this wait
        time.sleep(10)

    def checking_tag_changes(self):
        new_tag = os.environ["CONTRAIL_CONTAINER_TAG"]
        nodes = (os.environ["CONTROLLER_NODES"] + ',' + os.environ["AGENT_NODES"])
        nodes = nodes.replace(',', ' ').split(',')
        for node in nodes:
            host_fixture = self.useFixture(HostFixture(ssh_host=node))
            cmd = "sudo contrail-status | sed '/^$/q' | sed '1d;$d' | awk '{print $4}' | grep -v '^" + new_tag + "$'"
            stdout = host_fixture.exec_command(cmd)
            if stdout != '':
                raise Exception(f'contrail-status contains wrong tags\nnode: {node}\ncommand: {cmd}\noutput: {stdout}\n')

