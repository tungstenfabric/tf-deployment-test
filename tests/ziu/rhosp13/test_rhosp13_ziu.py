import os
import logging
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase

# TODO: allow to read log level from config
# TODO: move log level set into base class
logging.basicConfig(level=logging.INFO)


CURRENT_DIRECTORY = 'tests/ziu/rhosp13'


class Rhosp13ZiuTests(WithAttributes, DeploymentTestCase):
    @attr("rhosp13", "openstack", "ziu")
    def test_rhosp13_ziu(self):
        self.logger = logging.getLogger(__name__ + '.rhosp13_ziu')
        file_name = os.path.join(CURRENT_DIRECTORY, 'rhosp13_ziu.sh')
        self.run_test_remotely(file_name)
