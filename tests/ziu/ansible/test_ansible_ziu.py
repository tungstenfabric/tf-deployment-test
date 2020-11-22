import os
import logging
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase

# TODO: allow to read log level from config
# TODO: move log level set into base class
logging.basicConfig(level=logging.INFO)


CURRENT_DIRECTORY = 'tests/ziu/ansible'


class ZiuAnsibleTests(WithAttributes, DeploymentTestCase):

    @attr("ansible-openstack")
    def test_ansible_ziu(self):
        self.logger = logging.getLogger(__name__ + '.ansible_ziu')
        file_name = os.path.join(CURRENT_DIRECTORY, 'ansible_ziu.sh')
        self.run_test_remotely(file_name[1:])
