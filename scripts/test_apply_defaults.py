from my_fixtures.vnc_api_fixture import VncApiFixture
from my_fixtures.host_fixture import HostFixture
from testtools.testcase import attr, WithAttributes
from deployment_test import BaseTestCase
import logging
import os

logging.basicConfig(level=logging.INFO)


class ApplyDefaultsTests(WithAttributes, BaseTestCase):
    # ansible-kubernetes attr means deployer is k8s_manifests
    # and orchestrator  is kubernetes
    # this test will runs for k8s_manifests depplyer and kubernetes orchestrator
    @attr("all-deployers-all-orchestrator")
    def test_ansible_k8s_smoke(self):
        self.logger = logging.getLogger(__name__ + '.ansible_k8s_smoke')
        self.logger.info('Go test check')
        # -------------
        vnc_api_client = self.useFixture(VncApiFixture())
        # -------------
        encap_before_test = vnc_api_client.get_encap_priority()
        default_encap_priority = 'MPLSoUDP,MPLSoGRE,VXLAN'
        assert encap_before_test == default_encap_priority, f"ERROR: current encap_priority is not default {default_encap_priority}"
        # -------------
        new_encap_priority = 'VXLAN,MPLSoUDP,MPLSoGRE'
        vnc_api_client.set_encap_priority(new_encap_priority)
        encap_after_change = vnc_api_client.get_encap_priority()
        assert encap_before_test != encap_after_change, "ERROR: encap_priority was not changed by api"
        # -------------
        cont_name = "tf-deployment-test"
        self.restart_containers_without_our_container_by_name(cont_name)
        # -------------
        encap_after_restart = vnc_api_client.get_encap_priority()
        # -------------
        apply_defaults = os.getenv("APPLY_DEFAULTS", True)
        self.logger.info(f'apply_defaults is {apply_defaults}')
        if bool(apply_defaults):
            assert default_encap_priority == encap_after_restart, "ERROR: encap_priority was not reseted after restarting containers"
        else:
            assert encap_after_change == encap_after_restart, "ERROR: encap_priority was reseted after restarting containers"
        # ------------
        self.logger.info('apply_default test: PASSED')
