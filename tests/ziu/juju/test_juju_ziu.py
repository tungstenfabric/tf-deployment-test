import os
import logging
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase

# TODO: allow to read log level from config
# TODO: move log level set into base class
logging.basicConfig(level=logging.INFO)


CURRENT_DIRECTORY = 'tests/ziu/juju'


class JujuZiuTests(WithAttributes, DeploymentTestCase):
    @attr("juju", "openstack", "ziu")
    def test_juju_ziu(self):
        self.logger = logging.getLogger(__name__ + '.juju_ziu')
        file_name = os.path.join(CURRENT_DIRECTORY, 'juju_ziu.sh')
        self.run_test_remotely(file_name)
