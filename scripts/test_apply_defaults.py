from my_helpers.apply_defaults import TestApplyDefaultsCases
from testtools.testcase import attr, WithAttributes
import logging
import os

logging.basicConfig(level=logging.INFO)


class ApplyDefaultsTests(WithAttributes, TestApplyDefaultsCases):
    # ansible-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("ansible-kubernetes")
    def test_ansible_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.ansible_k8s_smoke')
        # -------------
        self.add_to_log('Go test check')
        # need close fixtures ssh connection
        self.close_ssh_connection()
        # -------------
        master_node = self.get_master_node()
        # -------------
        encap_before_test = self.get_encap_priority(master_node)
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        self.assert_encap_before_default(encap_before_test, default_encap_priority)
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.get_encap_priority(master_node)
        self.assert_encap_before_after_change(encap_before_test, encap_after_change)
        # -------------
        cont_name = "tf-deployment-test"
        self.restart_containers_without_our_container_by_name(cont_name)
        # -------------
        encap_after_restart = self.get_encap_priority(master_node)
        # -------------
        apply_defaults = self.get_apply_defaults_value_from_env()
        if apply_defaults == "true":
            self.assert_encap_default_after_restart(default_encap_priority, encap_after_restart)
        else:
            self.assert_encap_before_after_restart(encap_after_change, encap_after_restart)
        # ------------
        self.add_to_log('apply_default test: PASSED')
