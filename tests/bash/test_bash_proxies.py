import os
import logging
from testtools.testcase import attr, WithAttributes
from testtools import skipIf

from common.deployment_test_case import DeploymentTestCase

# TODO: allow to read log level from config
# TODO: move log level set into base class
logging.basicConfig(level=logging.INFO)


CURRENT_DIRECTORY = "tests/bash"


class BashTests(WithAttributes, DeploymentTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will be run for k8s_manifests deployer and kubernetes orchestrator
    @attr("k8s_manifests", "kubernetes")
    def test_check_agent_status(self):
        self.logger = logging.getLogger(__name__ + '.check_agent_status')
        file_name = os.path.join(CURRENT_DIRECTORY, 'check_agent_status.sh')
        self.run_test_remotely(file_name)

    @attr("juju", "hybrid")
    def test_k8s_keystone_auth(self):
        self.logger = logging.getLogger(__name__ + '.k8s_keystone_auth')
        file_name = os.path.join(CURRENT_DIRECTORY, 'k8s_keystone_auth.sh')
        self.run_test_remotely(file_name)

    @skipIf(os.getenv("ENABLE_NAGIOS", 'false') != 'true', "Skipped as nrpe isn't enabled")
    @attr("juju", "all-orchestrators")
    def test_juju_nrpe(self):
        self.logger = logging.getLogger(__name__ + '.juju_nrpe')
        file_name = os.path.join(CURRENT_DIRECTORY, 'juju_nrpe.sh')
        self.run_test_remotely(file_name)
