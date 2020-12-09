import os
import logging
import yaml
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase
from common.utils.vnc_api import VncApiProxy

import time
import testtools
from common.fixtures.host_fixture import HostFixture

# TODO: allow to set level in config
# TODO: move this to single base test class
# WIP for Juju
logging.basicConfig(level=logging.INFO)


class JujuAction(testtools.TestCase):

    def get_juju_encap_priorities(self):
        host_fixture = self.useFixture(HostFixture())
        cmd = 'juju config contrail-controller encap-priority'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        return my_out_data.strip().split(",")

    def set_juju_encap_priorities(self, encaps_list):
        encaps_str = f'{encaps_list[0]},{encaps_list[1]},{encaps_list[2]}'
        host_fixture = self.useFixture(HostFixture())
        cmd = f'juju config contrail-controller encap-priority={encaps_str}'
        host_fixture.exec_command(cmd)

    def juju_run_action_apply_defaults(self):
        host_fixture = self.useFixture(HostFixture())
        cmd = 'juju run-action contrail-controller/0 apply-defaults --wait'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        return my_out_data


class ApplyDefaultsTests(WithAttributes, DeploymentTestCase, JujuAction):

    @attr("ansible", "kubernetes")
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

    @attr("juju", "all-orchestrators")
    def test_juju_action_apply_defaults(self):
        self.logger = logging.getLogger(__name__ + '.test_juju_apply_defaults')
        self.logger.info('Go test check')
        original_juju_encap_priorities = self.get_juju_encap_priorities()
        vnc_api_client = VncApiProxy()
        original_api_encap_priorities = vnc_api_client.get_encap_priorities()
        self.logger.info(f'original_juju: {original_juju_encap_priorities} ; original_api: {original_api_encap_priorities}')
        try:
            assert original_juju_encap_priorities == original_api_encap_priorities, "ERROR: juju encap_priority differs from api encap_priority"

            new_juju_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
            if new_juju_encap_priorities == original_juju_encap_priorities:
                new_juju_encap_priorities = ['VXLAN', 'MPLSoGRE', 'MPLSoUDP']
            self.set_juju_encap_priorities(new_juju_encap_priorities)
            current_juju_encap_priorities = self.get_juju_encap_priorities()
            self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_juju: {current_juju_encap_priorities}')
            assert new_juju_encap_priorities == current_juju_encap_priorities, "ERROR: encap_priority was not set or set incorrectly by juju"

            current_api_encap_priorities = vnc_api_client.get_encap_priorities()
            self.logger.info(f'original_api: {original_api_encap_priorities} ; current_api_before: {current_api_encap_priorities}')
            assert original_api_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was changed"

            result_apply_defaults = self.juju_run_action_apply_defaults()
            self.logger.info(f'result_apply_defaults: {result_apply_defaults}')

            current_api_encap_priorities = vnc_api_client.get_encap_priorities()
            self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_api_after: {current_api_encap_priorities}')
            assert new_juju_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was not set or set incorrectly"
        finally:
            default_juju_encap_priorities = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']
            if default_juju_encap_priorities != self.get_juju_encap_priorities():
                self.set_juju_encap_priorities(default_juju_encap_priorities)
                result_apply_defaults = self.juju_run_action_apply_defaults()
                self.logger.info(f'result_apply_defaults_for_default: {result_apply_defaults}')
                self.logger.info(f'result_get_juju_encap_priorities: {self.get_juju_encap_priorities()}')

        self.logger.info('apply_default test: PASSED')
