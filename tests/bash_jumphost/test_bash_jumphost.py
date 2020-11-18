from common.deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging
import os

logging.basicConfig(level=logging.INFO)

class BashJumphostTests(WithAttributes,BaseTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("k8s_manifests-kubernetes")
    def test_manifests_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.manifests_k8s_smoke')
        current_directory = 'tests/test_bash_jumphost'
        file_name = os.path.join(current_directory, 'k8s_manifests_k8s.sh')
        self.run_bash_test_on_host(file_name)

    @attr("juju-all")
    def test_k8s_auth_keystone(self):
        self.logger = logging.getLogger(__name__ + '.k8s_auth_keystone')
        current_directory = 'tests/bash_jumphost'
        file_name = os.path.join(current_directory, 'k8s_auth_keystone.sh')
        self.run_bash_test_on_host(file_name)
