from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging

logging.basicConfig(level=logging.INFO)

class BashApplyDefaultsTests(WithAttributes,BaseTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("ansible-kubernetes")
    def test_ansible_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.manifests_k8s_smoke')
        self.run_bash_test_on_host('test_apply_defaults.sh')