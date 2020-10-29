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
        self.add_to_log('Go test check')
        # Python way
        my_dir = "tf-deployment-test"
        cont_name = "tf-deployment-test-apply"
        # need move ssh fixture
        master_node = self.get_master_node(os.environ["CONTROLLER_NODES"])
        self.add_to_log(f'master_node is {master_node}')
        encap_before_test = self.get_encap_priority(master_node)
        self.add_to_log(f'encap_before_test is {encap_before_test}')
        # we connected on node
        self.add_to_log(f'encap_before_test is {encap_before_test}')
        self.emul_fixture_setUp(master_node)
        self.check_cmd_on_node_by_ssh("pwd")
        test_container_id = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}')
        containers_for_reboot = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q | grep -v ^{test_container_id}')
        # -------------
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        self.run_cmd_here(f'echo expected default_encap_priority is {default_encap_priority}')
        # assert encap_before_test != default_encap_priority, f"ERROR: current encap_priority is not default {default_encap_priority}"
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.add_to_log(f"we begining set encap_priority = {new_encap_priority}")
        self.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_change is {encap_after_change}")
        # assert encap_before_test != encap_after_change, "ERROR: encap_priority was not changed by api"
        # -------------
        # get apply_defaults value from instances.yaml
        instances_yaml_file = "tf-ansible-deployer/instances.yaml"
        self.check_cmd_on_node_by_ssh(f"if cat {instances_yaml_file} | grep 'APPLY_DEFAULTS: \"false\"' ; then echo false ; else true ; fi")
        apply_defaults = self.apply_defaults_from_instances_yaml(instances_yaml_file)
        self.add_to_log(f'apply_defaults is {apply_defaults}')
        # ------------
        self.add_to_log('Prodolzhenie sleduet..')
