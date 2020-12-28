import logging
import os
import sys
import testtools
import time

from common.fixtures.host_fixture import HostFixture
from common.utils.vnc_api import VncApiProxy


def initLogger():
    level = logging.DEBUG if os.environ.get('DEBUG', False) else logging.INFO
    handler = logging.StreamHandler(sys.stderr)
    handler.setLevel(level)
    handler.setFormatter(logging.Formatter(
        '%(asctime)s.%(msecs)03d %(levelname)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'))
    l = logging.getLogger()
    l.setLevel(level)
    l.addHandler(handler)
    return l


logger = initLogger()


class DeploymentTestCase(testtools.testcase.WithAttributes, testtools.TestCase):

    @classmethod
    def setUpClass(cls):
        # init logging
        global logger
        cls.logger = logger
        # init host fixture
        cls.ssh_host = os.getenv("SSH_HOST")
        cls.ssh_user = os.getenv("SSH_USER")
        cls.host_fixture = cls.useFixture(
            HostFixture(cls.ssh_host, cls.ssh_user, cls.logger))
        cls.vnc_api_client = VncApiProxy(cls.logger)

    def run_test_remotely(self, test_file):
        remote_path = self.host_fixture.get_remote_path(test_file)
        self.host_fixture.exec_command(remote_path)

    def get_controller_nodes(self):
        # list can be space or comma separated
        return os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")

    def restart_containers(self, name_filter=""):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        for node in self.get_controller_nodes():
            hf = self.useFixture(
                HostFixture(node, self.ssh_user, self.logger))
            containers = hf.exec_command_result(
                f'sudo docker ps -q -f name={name_filter}')
            hf.exec_command(
                'sudo docker restart ' + ' '.join(containers.split()))

        # TODO: use correct wait. think about usefulness of this wait
        time.sleep(10)
