from my_helpers.apply_defaults import TestApplyDefaultsCases
from my_fixtures.vnc_api_fixture import VncApiFixture
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
        self.vnc_api_client = self.useFixture(VncApiFixture())
        # -------------
        self.logger.info('Go test check')
        # need close fixtures ssh connection
        self.host_fixture._client.close()
        self.logger.info('_client.close')
        # -------------
        master_node = self.get_master_node()
        # -------------
        encap_before_test = self.vnc_api_client.get_encap_priority(master_node)
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        assert encap_before_test == default_encap_priority, f"ERROR: current encap_priority is not default {default_encap_priority}"
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        self.vnc_api_client.set_encap_priority(new_encap_priority, master_node)
        encap_after_change = self.vnc_api_client.get_encap_priority(master_node)
        assert encap_before_test != encap_after_change, "ERROR: encap_priority was not changed by api"
        # -------------
        cont_name = "tf-deployment-test"
        self.restart_containers_without_our_container_by_name(cont_name)
        # -------------
        encap_after_restart = self.vnc_api_client.get_encap_priority(master_node)
        # -------------
        apply_defaults = self.get_apply_defaults_value_from_env()
        if bool(apply_defaults):
            assert default_encap_priority == encap_after_restart, "ERROR: encap_priority was not reseted after restarting containers"
        else:
            assert encap_after_change == encap_after_restart, "ERROR: encap_priority was reseted after restarting containers"
        # ------------
        self.logger.info('apply_default test: PASSED')
