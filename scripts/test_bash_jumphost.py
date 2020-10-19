from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging

logging.basicConfig(level=logging.INFO)

class BashJumphostTests(WithAttributes,BaseTestCase):
    def test_sample_error(self):
        self.logger = logging.getLogger(__name__ + '.test1')
        self.run_bash_test_on_host('test_sample_error.sh')

    def test_sample_success(self):
        self.logger = logging.getLogger(__name__ + '.test2')
        self.run_bash_test_on_host('test_sample_success.sh')

    # manifests_and_kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("k8s_manifests-kubernetes")
    def test_manifests_k8s_smoke(self):
        seld.logger = logging.getLogger(__name__ + '.manifests_k8s_smoke')
        self.run_bash_test_on_host('k8s_manifests_k8s.sh')