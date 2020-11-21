import os
import logging
import yaml
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase
from common.utils.vnc_api import VncApiProxy

# TODO: allow to set level in config
# TODO: move this to single base test class
logging.basicConfig(level=logging.INFO)


class ApplyDefaultsTests(WithAttributes, DeploymentTestCase):

    @attr("all-deployers-all-orchestrator")
    def test_apply_defaults(self):
        self.logger = logging.getLogger(__name__ + '.test_apply_defaults')
        self.logger.info('Go test check')
        vnc_api_client = VncApiProxy()

        original_encap_priorities = vnc_api_client.get_encap_priorities()
        self.logger.info(f'current_encap_priorities is {original_encap_priorities}')

        try:
            new_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
            if new_encap_priorities == original_encap_priorities:
                new_encap_priorities = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']

            vnc_api_client.set_encap_priorities(new_encap_priorities)
            current_encap_priorities = vnc_api_client.get_encap_priorities()
            assert new_encap_priorities == current_encap_priorities, "ERROR: encap_priority was not set or set incorrectly by api"

            self.restart_containers(name_filter="provisioner")

            current_encap_priorities = vnc_api_client.get_encap_priorities()
            apply_defaults = yaml.load(os.getenv("APPLY_DEFAULTS", 'true'))
            self.logger.info(f'apply_defaults is {apply_defaults}')
            if bool(apply_defaults):
                assert original_encap_priorities == current_encap_priorities, "ERROR: encap_priority was not reset after restarting containers"
            else:
                assert current_encap_priorities == new_encap_priorities, "ERROR: encap_priority was reset after restarting containers"

            self.logger.info('apply_default test: PASSED')
        finally:
            # TODO: rework this to resources that must be restored
            vnc_api_client.set_encap_priorities(original_encap_priorities)
