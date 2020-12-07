import logging
import os
from common.fixtures.host_fixture import HostFixture


class JujuAction(object):

    def __init__(self):
        self.logger = logging.getLogger(__name__ + '.JujuAction')
        # list can be space or comma separated
        controller_nodes = os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")
        # TODO: add keystone creds
        # TODO: add ssl
        self.logger.info(f'api_servers: {controller_nodes}')
        self.vnc_lib = vnc_api.VncApi(api_server_host=controller_nodes)

    def get_juju_encap_priorities(self):
        host_fixture = self.useFixture(HostFixture())
        cmd = 'juju config contrail-controller encap-priority'
        my_out_data, my_err_data = host_fixture.exec_command(cmd)
        self.logger.info('cmd result: ', my_out_data, ' garry ', my_err_data)
        return my_out_data
