import logging
import fixtures
import os
from vnc_api.vnc_api import EncapsulationPrioritiesType
from vnc_api import vnc_api

logging.basicConfig(level=logging.INFO)


class VncApiFixture(fixtures.Fixture):
    def _setUp(self):
        self.logger = logging.getLogger(__name__ + '.VncApiFixture')
        self.master_node = self.get_master_node()
        self.vnc_lib = vnc_api.VncApi(api_server_host=self.master_node)
        self.fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        self.addCleanup(delattr, self, 'master_node')
        self.addCleanup(delattr, self, 'vnc_lib')
        self.addCleanup(delattr, self, 'fq_name')

    @staticmethod
    def get_array_controller_nodes():
        controller_nodes = os.environ["CONTROLLER_NODES"]
        array_controller_nodes = controller_nodes.replace(",", " ").split()
        return array_controller_nodes

    def get_master_node(self):
        array_controller_nodes = self.get_array_controller_nodes()
        master_node = array_controller_nodes[0]
        self.logger.info(f'master_node is {master_node}')
        return master_node

    def get_encap_priority(self):
        # TODO: add supproting SSL
        # my_fq_name type list
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        current_encap_priority = gr_obj.get_encapsulation_priorities()
        res = str(current_encap_priority)[17:-1].replace("'", "").replace(" ", "")
        self.logger.info(f'current_encap_priority is {res}')
        return res
        # before "encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
        # after "MPLSoUDP,MPLSoGRE,VXLAN"

    def set_encap_priority(self, encaps):
        # TODO: add supproting SSL
        self.logger.info(f"we begining set encap_priority = {encaps}")
        new_encap = encaps.split(",")
        encap_obj = EncapsulationPrioritiesType(encapsulation=new_encap)
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=self.fq_name)
        gr_obj.set_encapsulation_priorities(encap_obj)
        self.vnc_lib.global_vrouter_config_update(gr_obj)
