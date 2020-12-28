import logging
import os
import sys
import testtools
import time

from common.fixtures.host_fixture import HostFixture
from common.utils.vnc_api import VncApiProxy

from testtools.testcase import WithAttributes


class DeploymentTestCase(WithAttributes, testtools.TestCase):

    def __init__(self, ssh_host=None, ssh_user=None):
        # init logging
        level = logging.DEBUG if os.environ.get('DEBUG', False) else logging.INFO
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(level)
        handler.setFormatter(logging.Formatter(
            '%(asctime)s.%(msecs)03d %(levelname)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'))
        self.logger = logging.getLogger()
        self.logger.setLevel(level)
        self.logger.addHandler(handler)
        # init host fixture
        self.ssh_host = ssh_host if ssh_host else os.getenv("SSH_HOST")
        self.ssh_user = ssh_user if ssh_user else os.getenv("SSH_USER")

    def setUp(self):
        self.host_fixture = self.useFixture(
            HostFixture(self.ssh_host, self.ssh_user, self.logger))
        self.vnc_api_client = VncApiProxy(self.logger)

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
