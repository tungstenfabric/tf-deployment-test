import logging
import os

from vnc_api.vnc_api import EncapsulationPrioritiesType
from vnc_api import vnc_api


class VncApiProxy(object):

    def __init__(self):
        self.logger = logging.getLogger(__name__ + '.VncApiPropxy')
        # list can be space or comma separated
        controller_nodes = os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")
        # TODO: add keystone creds
        # TODO: add ssl
        self.vnc_lib = vnc_api.VncApi(api_server_host=controller_nodes)
        self.fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        self.addCleanup(delattr, self, 'vnc_lib')
        self.addCleanup(delattr, self, 'fq_name')

    def get_encap_priorities(self):
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        encap_obj = gr_obj.get_encapsulation_priorities()
        if not encap_obj:
            return ['', '', '']
        encaps = encap_obj.encapsulation
        encaps.extend([''] * (3 - len(encaps)))
        return encaps

    def set_encap_priority(self, encaps):
        encap_obj = EncapsulationPrioritiesType(encapsulation=encaps)
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        gr_obj.set_encapsulation_priorities(encap_obj)
        self.vnc_lib.global_vrouter_config_update(gr_obj)
