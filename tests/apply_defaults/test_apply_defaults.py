import os
import yaml
from testtools.testcase import attr

from common.deployment_test_case import DeploymentTestCase


class ApplyDefaultsTests(DeploymentTestCase):

    @attr("ansible", "kubernetes")
    def test_apply_defaults(self):
        original_encap_priorities = self.vnc_api_client.get_encap_priorities()
        self.logger.info(f'current_encap_priorities is {original_encap_priorities}')

        try:
            new_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
            if new_encap_priorities == original_encap_priorities:
                new_encap_priorities = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']

            self.vnc_api_client.set_encap_priorities(new_encap_priorities)
            current_encap_priorities = self.vnc_api_client.get_encap_priorities()
            assert new_encap_priorities == current_encap_priorities, "ERROR: encap_priority was not set or set incorrectly by api"

            self.restart_containers(name_filter="provisioner")

            current_encap_priorities = self.vnc_api_client.get_encap_priorities()
            apply_defaults = yaml.load(os.getenv("APPLY_DEFAULTS", 'true'))
            self.logger.info(f'apply_defaults is {apply_defaults}')
            if bool(apply_defaults):
                assert original_encap_priorities == current_encap_priorities, "ERROR: encap_priority was not reset after restarting containers"
            else:
                assert current_encap_priorities == new_encap_priorities, "ERROR: encap_priority was reset after restarting containers"

            self.logger.info('apply_default test: PASSED')
        finally:
            # TODO: rework this to resources that must be restored
            self.vnc_api_client.set_encap_priorities(original_encap_priorities)

    @attr("juju", "all-orchestrators")
    def test_juju_action_apply_defaults(self):
        self.logger.info('Go test check')
        config_get_cmd = 'juju config tf-controller encap-priority'
        config_set_cmd = 'juju config tf-controller encap-priority={}'
        apply_cmd = 'juju run-action tf-controller/0 apply-defaults --wait'

        original_juju_encap_priorities = self.host_fixture.exec_command_result(config_get_cmd).strip().split(",")
        original_api_encap_priorities = self.vnc_api_client.get_encap_priorities()
        self.logger.info(f'original_juju: {original_juju_encap_priorities} ; original_api: {original_api_encap_priorities}')
        assert original_juju_encap_priorities == original_api_encap_priorities, "ERROR: juju encap_priority differs from api encap_priority"

        new_juju_encap_priorities = ['VXLAN', 'MPLSoUDP', 'MPLSoGRE']
        if new_juju_encap_priorities == original_juju_encap_priorities:
            new_juju_encap_priorities = ['VXLAN', 'MPLSoGRE', 'MPLSoUDP']
        try:
            self.host_fixture.exec_command(config_set_cmd.format(','.join(new_juju_encap_priorities)))

            current_api_encap_priorities = self.vnc_api_client.get_encap_priorities()
            self.logger.info(f'original_api: {original_api_encap_priorities} ; current_api_before: {current_api_encap_priorities}')
            assert original_api_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was changed"

            result_apply_defaults = self.host_fixture.exec_command_result(apply_cmd)
            self.logger.info(f'result_apply_defaults: {result_apply_defaults}')

            current_api_encap_priorities = self.vnc_api_client.get_encap_priorities()
            self.logger.info(f'new_juju: {new_juju_encap_priorities} ; current_api_after: {current_api_encap_priorities}')
            assert new_juju_encap_priorities == current_api_encap_priorities, "ERROR: api encap_priority was not set or set incorrectly"
        finally:
            self.host_fixture.exec_command(config_set_cmd.format(','.join(original_api_encap_priorities)))
            finally_apply_defaults = self.host_fixture.exec_command_result(apply_cmd)
            self.logger.info(f'finally_apply: {finally_apply_defaults}')

        self.logger.info('juju_action_apply_default test: PASSED')
