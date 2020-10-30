from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging
import os
import time
import datetime

logging.basicConfig(level=logging.INFO)


class BashApplyDefaultsTests(WithAttributes,BaseTestCase):
    # k8s_manifests-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("ansible-kubernetes")
    def test_ansible_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.ansible_k8s_smoke')
        # -------------
        self.add_to_log('Go test check')
        master_node = self.get_master_node()
        self.add_to_log(f'master_node is {master_node}')
        encap_before_test = self.get_encap_priority(master_node)
        self.add_to_log(f'encap_before_test is {encap_before_test}')
        # -------------
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        self.add_to_log(f'expected default_encap_priority is {default_encap_priority}')
        assert encap_before_test == default_encap_priority, f"ERROR: current encap_priority is not default {default_encap_priority}"
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.add_to_log(f"we begining set encap_priority = {new_encap_priority}")
        self.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_change is {encap_after_change}")
        assert encap_before_test != encap_after_change, "ERROR: encap_priority was not changed by api"
        # -------------
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        array_controller_nodes = self.get_array_controller_nodes()
        cont_name = "tf-deployment-test-apply"
        for machine in array_controller_nodes:
            # open ssh connection
            self.create_ssh_connection(machine)
            self.check_cmd_on_node_by_ssh("ip a")
            test_container_id = self.check_cmd_on_node_by_ssh(f'sudo docker ps -q -f name={cont_name}').strip()
            if test_container_id == "":
                reboot_command = f"sudo docker restart $(sudo docker ps -q &>/dev/null"
            else:
                reboot_command = f"sudo docker restart $(sudo docker ps -q | grep -v ^{test_container_id}) &>/dev/null"
            self.check_cmd_on_node_by_ssh("sudo docker ps")
            self.add_to_log(f'Before reboot: {datetime.datetime.now()}')
            self.check_cmd_on_node_by_ssh(reboot_command)
            time.sleep(60)
            self.add_to_log(f'After reboot: {datetime.datetime.now()}')
            self.check_cmd_on_node_by_ssh("sudo docker ps")
            self.close_ssh_connection()
        # -------------
        encap_after_restart = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_restart is {encap_after_restart}")
        # -------------
        # get APPLY_DEFAULTS value from instances.yaml
        instances_yaml_file = "tf-ansible-deployer/instances.yaml"
        self.create_ssh_connection(master_node)
        instances_yaml = self.check_cmd_on_node_by_ssh(f"cat {instances_yaml_file}")
        self.close_ssh_connection()
        apply_defaults = self.apply_defaults_from_instances_yaml(instances_yaml)
        self.add_to_log(f'apply_defaults is {apply_defaults}')
        # ------------
        if apply_defaults == "true":
            assert default_encap_priority == encap_after_restart, "ERROR: encap_priority was not reseted after restarting containers"
        else:
            assert encap_after_change == encap_after_restart, "ERROR: encap_priority was reseted after restarting containers"
        # ------------
        self.add_to_log('apply_default test: PASSED')
