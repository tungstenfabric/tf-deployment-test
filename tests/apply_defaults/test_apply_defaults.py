import os
import logging
import yaml
from testtools.testcase import attr, WithAttributes

from common.deployment_test_case import DeploymentTestCase
from common.utils.vnc_api import VncApiProxy
from common.fixtures.host_fixture import HostFixture

# TODO: allow to set level in config
# TODO: move this to single base test class
logging.basicConfig(level=logging.INFO)


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
        host_fixture = self.useFixture(HostFixture())
        vnc_api_client = VncApiProxy()
        juju_config_cmd = 'juju config contrail-controller encap-priority'
        apply_cmd = 'juju run-action contrail-controller/0 apply-defaults --wait'

        original_api_encap_priorities = vnc_api_client.get_encap_priorities()
        original_juju_encap_priorities = host_fixture.exec_command(juju_config_cmd)[0].strip().split(",")
        self.logger.info(f'original_juju: {original_juju_encap_priorities} ; original_api: {original_api_encap_priorities}')
        try:
            assert original_juju_encap_priorities == original_api_encap_priorities, "ERROR: juju encap_priority differs from api encap_priority"

            new_juju_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
            if new_juju_encap_priorities == original_juju_encap_priorities:
                new_juju_encap_priorities = ['VXLAN', 'MPLSoGRE', 'MPLSoUDP']
            encaps = new_juju_encap_priorities
            host_fixture.exec_command(f'{juju_config_cmd}={encaps[0]},{encaps[1]},{encaps[2]}')
            current_juju_encap_priorities = host_fixture.exec_command(juju_config_cmd)[0].strip().split(",")
            self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_juju: {current_juju_encap_priorities}')
            assert new_juju_encap_priorities == current_juju_encap_priorities, "ERROR: encap_priority was not set or set incorrectly by juju"

            current_api_encap_priorities = vnc_api_client.get_encap_priorities()
            self.logger.info(f'original_api: {original_api_encap_priorities} ; current_api_before: {current_api_encap_priorities}')
            assert original_api_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was changed"

            self.logger.info(f'result_apply_defaults: {host_fixture.exec_command(apply_cmd)[0]}')

            current_api_encap_priorities = vnc_api_client.get_encap_priorities()
            self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_api_after: {current_api_encap_priorities}')
            assert new_juju_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was not set or set incorrectly"
        finally:
            default_juju_encap_priorities = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']
            current_juju_encap_priorities = host_fixture.exec_command(juju_config_cmd)[0].strip().split(",")
            if default_juju_encap_priorities != current_juju_encap_priorities:
                encaps = default_juju_encap_priorities
                host_fixture.exec_command(f'{juju_config_cmd}={encaps[0]},{encaps[1]},{encaps[2]}')
                self.logger.info(f'result_apply_defaults_for_default: {host_fixture.exec_command(apply_cmd)[0]}')

        self.logger.info('juju_action_apply_default test: PASSED')
