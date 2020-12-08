import logging
import os
import testtools
from common.fixtures.host_fixture import HostFixture


class JujuAction(testtools.TestCase):

    def get_juju_encap_priorities(self):
        host_fixture = self.useFixture(HostFixture())
        cmd = 'juju config contrail-controller encap-priority'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        self.logger.info(f'cmd result: {my_out_data} garry {my_err_data}')
        return my_out_data

    def set_juju_encap_priorities(self, encaps):
        host_fixture = self.useFixture(HostFixture())
        cmd = f'juju config contrail-controller encap-priority={encaps}'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        self.logger.info(f'cmd result: {my_out_data} harry {my_err_data}')

    def juju_run_action_apply_defaults(self):
        host_fixture = self.useFixture(HostFixture())
        cmd = 'juju run-action contrail-controller/leader apply-defaults'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        self.logger.info(f'cmd result: {my_out_data} mary {my_err_data}')
        # TODO: use correct wait. think about usefulness of this wait
        time.sleep(10)
        return my_out_data
