from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging
import os

logging.basicConfig(level=logging.INFO)


class BashApplyDefaultsTests(WithAttributes,BaseTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("ansible-kubernetes")
    def test_ansible_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.ansible_k8s_smoke')
        self.run_cmd_here('echo Go test check')
        self.run_cmd_here('pwd')
        self.run_cmd_here('ls -la')
        self.run_cmd_here('printenv')
        # Python way
        my_dir = "tf-deployment-test"
        cont_name = "tf-deployment-test-apply"
        # need move ssh fixture
        # test_container_id = self.check_cmd_on_host(f'sudo docker ps -q -f name={cont_name}')
        # containers_for_reboot = self.check_cmd_on_host(f'sudo docker ps -q | grep -v ^{test_container_id}')
        master_node = self.get_master_node(os.environ["CONTROLLER_NODES"])
        encap_before_test = self.get_encap_priority(master_node)
        self.run_cmd_here(f'echo encap_before_test is {encap_before_test}')
        self.run_cmd_here('echo Prodolzhenie sleduet..')
