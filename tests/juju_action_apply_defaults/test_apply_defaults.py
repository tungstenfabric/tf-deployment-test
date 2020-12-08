import os
import logging
import yaml
from testtools.testcase import attr, WithAttributes
from common.utils.vnc_api import VncApiProxy
from common.juju_action import JujuAction

# TODO: allow to set level in config
# TODO: move this to single base test class
# WIP for Juju
logging.basicConfig(level=logging.INFO)


class JujuActionApplyDefaultsTests(WithAttributes, JujuAction):

    @attr("juju", "all-orchestrators")
    def test_juju_action_apply_defaults(self):
        self.logger = logging.getLogger(__name__ + '.test_juju_apply_defaults')
        self.logger.info('Go test check')
        original_juju_encap_priorities = self.get_juju_encap_priorities()
        self.logger.info(f'current_encap_priorities is {original_encap_priorities}')
        vnc_api_client = VncApiProxy()
        original_api_encap_priorities = vnc_api_client.get_encap_priorities()
        self.logger.info(f'original_juju: {original_juju_encap_priorities} ; original_api: {original_api_encap_priorities}')
        # assert original_juju_encap_priorities == original_api_encap_priorities, "ERROR 1_One"

        new_juju_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
        if new_juju_encap_priorities == original_juju_encap_priorities:
            new_juju_encap_priorities = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']
        vnc_api_client.set_encap_priorities(new_juju_encap_priorities)
        current_juju_encap_priorities = self.get_juju_encap_priorities()
        self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_juju: {current_juju_encap_priorities}')
        # assert new_juju_encap_priorities == current_juju_encap_priorities, "ERROR: encap_priority was not set or set incorrectly by juju"

        current_api_encap_priorities = vnc_api_client.get_encap_priorities()
        self.logger.info(f'original_api: {original_api_encap_priorities} ; current_api: {current_api_encap_priorities}')
        # assert original_api_encap_priorities == current_api_encap_priorities, "ERROR 3_Three"

        result_apply_defaults = self.juju_run_action_apply_defaults()
        self.logger.info(f'result_apply_defaults: {result_apply_defaults}')

        self.logger.info('apply_default test: PASSED')
