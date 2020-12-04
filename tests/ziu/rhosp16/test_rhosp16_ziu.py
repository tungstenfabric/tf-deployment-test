import os
import logging
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase

# TODO: allow to read log level from config
# TODO: move log level set into base class
logging.basicConfig(level=logging.INFO)


CURRENT_DIRECTORY = 'tests/ziu/rhosp13'


class Rhosp16ZiuTests(WithAttributes, DeploymentTestCase):
    @attr("rhosp16", "openstack", "ziu")
    def test_rhosp16_ziu(self):
        self.logger = logging.getLogger(__name__ + '.rhosp16_ziu')
        file_name = os.path.join(CURRENT_DIRECTORY, 'rhosp16_ziu.sh')
        self.run_test_remotely(file_name)
