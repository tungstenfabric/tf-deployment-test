from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging
import os
import time

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
        cont_name = "tf-deployment-test-apply"
        master_node = self.get_master_node()
        self.add_to_log(f'master_node is {master_node}')
        encap_before_test = self.get_encap_priority(master_node)
        self.add_to_log(f'encap_before_test is {encap_before_test}')
        # -------------
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        self.add_to_log(f'expected default_encap_priority is {default_encap_priority}')
        # assert encap_before_test != default_encap_priority, f"ERROR: current encap_priority is not default {default_encap_priority}"
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.add_to_log(f"we begining set encap_priority = {new_encap_priority}")
        self.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_change is {encap_after_change}")
        # assert encap_before_test != encap_after_change, "ERROR: encap_priority was not changed by api"
        # -------------
        # connected to master-node
        self.emul_fixture_setUp(master_node)
        self.check_cmd_on_node_by_ssh("pwd")
        test_container_id = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}').strip()
        # containers_for_reboot = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q | grep -v ^{test_container_id}')
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        #array_controller_nodes = self.get_array_controller_nodes()
        #for machine in array_controller_nodes:
            #self.emul_fixture_setUp(machine)
        self.check_cmd_on_node_by_ssh(f"sudo docker restart $(sudo docker ps -q | grep -v ^{test_container_id}) &>/dev/null")
        time.sleep(600)
        self.check_cmd_on_node_by_ssh(f"sudo docker ps")
        # -------------
        encap_after_restart = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_restart is {encap_after_restart}")
        # -------------
        # get APPLY_DEFAULTS value from instances.yaml
        instances_yaml_file = "tf-ansible-deployer/instances.yaml"
        instances_yaml = self.check_cmd_on_node_by_ssh(f"cat {instances_yaml_file}")
        apply_defaults = self.apply_defaults_from_instances_yaml(instances_yaml)
        self.add_to_log(f'apply_defaults is {apply_defaults}')
        # ------------
        if apply_defaults == "true":
            self.add_to_log("true fetch")
            if default_encap_priority != encap_after_restart:
                self.add_to_log("ERROR: encap_priority was not reseted after restarting containers")
        else:
            self.add_to_log("else fetch")
            if encap_before_test == encap_after_restart:
                self.add_to_log("ERROR: encap_priority was reseted after restarting containers")
        # ------------
        self.add_to_log('Prodolzhenie sleduet..')
