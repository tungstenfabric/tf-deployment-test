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
