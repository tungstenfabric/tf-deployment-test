import logging
import os
import sys
import testtools
import time
import json

from common.fixtures.host_fixture import HostFixture
from common.utils.vnc_api import VncApiProxy


def initLogger():
    level = logging.DEBUG if os.environ.get('DEBUG', True) else logging.INFO
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    formatter = logging.Formatter(
        '%(asctime)s.%(msecs)03d %(levelname)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S')
    # use stderr as stdout is replaced by testr
    handler = logging.StreamHandler(sys.stderr)
    handler.setLevel(level)
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)
    return root_logger


logger = initLogger()


class DeploymentTestCase(testtools.testcase.WithAttributes, testtools.TestCase):

    @classmethod
    def setUpClass(cls):
        global logger
        cls.logger = logger
        cls.ssh_host = os.getenv("SSH_HOST")
        cls.ssh_user = os.getenv("SSH_USER")
        # list can be space or comma separated
        cls.controller_nodes = os.getenv(
            "CONTROLLER_NODES", "").replace(" ", ",").split(",")
        cls.vnc_api_client = VncApiProxy(cls.controller_nodes, cls.logger)
        cls.host_fixture = HostFixture(cls.ssh_host, cls.ssh_user, cls.logger)
        cls.host_fixture.setUp()

    @classmethod
    def tearDownClass(cls):
        cls.host_fixture.cleanUp()

    def run_test_remotely(self, test_file):
        remote_path = self.host_fixture.get_remote_path(test_file)
        self.host_fixture.exec_command(remote_path, log_output=True)

    def restart_containers(self, name_filter=""):
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        for node in self.controller_nodes:
            hf = self.useFixture(
                HostFixture(node, self.ssh_user, self.logger))
            containers = hf.exec_command_result(
                f'sudo docker ps -q -f name={name_filter}')
            hf.exec_command(
                'sudo docker restart ' + ' '.join(containers.split()))
        # TODO: use correct wait. think about usefulness of this wait
        time.sleep(10)

    def check_container_tags(self, tag):
        nodes = (os.getenv("CONTROLLER_NODES") + ',' +
                 os.getenv("AGENT_NODES")).replace(' ', ',').split(',')
        for node in nodes:
            host_fixture = self.useFixture(HostFixture(ssh_host=node))
            cmd = 'sudo contrail-status --format json'
            result = host_fixture.exec_command_result(cmd)
            contrail_status_obj = json.loads(result.replace('\\', ''))
            for item in contrail_status_obj.get('containers').items():
                if item[1].get('Original Version') != tag:
                    raise Exception('WARNING: {}\'s tag {} != {}'.format(
                                    item[0], item[1].get('Original Version'), tag))

