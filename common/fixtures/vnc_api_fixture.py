import logging
import fixtures
import os
from vnc_api.vnc_api import EncapsulationPrioritiesType
from vnc_api import vnc_api


# TODO: why it's fixture?
class VncApiFixture(fixtures.Fixture):
    def _setUp(self):
        self.logger = logging.getLogger(__name__ + '.VncApiFixture')
        # list can be space or comma separated
        controller_nodes = os.environ["CONTROLLER_NODES"].replace(",", " ").split(",")
        # TODO: add keystone creds
        # TODO: add ssl
        self.vnc_lib = vnc_api.VncApi(api_server_host=controller_nodes)
        self.fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        self.addCleanup(delattr, self, 'vnc_lib')
        self.addCleanup(delattr, self, 'fq_name')

    # TODO: move this helper out to usage place
    def get_encap_priority(self):
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        current_encap_priority = gr_obj.get_encapsulation_priorities()
        # what's the magic with 17???
        res = str(current_encap_priority)[17:].replace("'", "").replace(" ", "")
        self.logger.info(f'current_encap_priority is {res}')
        return res

    # TODO: move this helper out to usage place
    def set_encap_priority(self, encaps):
        new_encap = encaps.split(",")
        encap_obj = EncapsulationPrioritiesType(encapsulation=new_encap)
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        gr_obj.set_encapsulation_priorities(encap_obj)
        self.vnc_lib.global_vrouter_config_update(gr_obj)
