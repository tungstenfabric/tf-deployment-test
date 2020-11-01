from deployment_test import BaseTestCase
from testtools.testcase import attr, WithAttributes
import logging
import os
import time
import datetime

logging.basicConfig(level=logging.INFO)


class BashApplyDefaultsTests(WithAttributes,BaseTestCase):
    # ansible-kubernetes attr means deployer is k8s_manifests
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
        assert_logic_default = (encap_before_test == default_encap_priority)
        assert_message_default = f"ERROR: current encap_priority is not default {default_encap_priority}"
        self.assert_with_logs(assert_logic_default, assert_message_default)
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_change is {encap_after_change}")
        # -------------
        assert_logic_changed = (encap_before_test != encap_after_change)
        assert_message_changed = "ERROR: encap_priority was not changed by api"
        self.assert_with_logs(assert_logic_changed, assert_message_changed)
        # -------------
        # TODO: reboot only contrail containers
        # but now we reboot all another containers
        array_controller_nodes = self.get_array_controller_nodes()
        cont_name = "tf-deployment-test"
        for machine in array_controller_nodes:
            our_container_id = self.reboot_containers_without_our_container_by_name(machine, cont_name)
            self.add_to_log(f'on machine {machine}: our_container_id = _{our_container_id}_')
        # -------------
        encap_after_restart = self.get_encap_priority(master_node)
        self.add_to_log(f"encap_after_restart is {encap_after_restart}")
        # -------------
        apply_defaults = self.get_apply_defaults_value_from_env()
        if apply_defaults == "true":
            assert_logic_apply_true = (default_encap_priority == encap_after_restart)
            assert_message_apply_true = "ERROR: encap_priority was not reseted after restarting containers"
            self.assert_with_logs(assert_logic_apply_true, assert_message_apply_true)
        else:
            assert_logic_apply_false = (encap_after_change == encap_after_restart)
            assert_message_apply_false = "ERROR: encap_priority was reseted after restarting containers"
            self.assert_with_logs(assert_logic_apply_false, assert_message_apply_false)
        # ------------
        self.add_to_log('apply_default test: PASSED')
