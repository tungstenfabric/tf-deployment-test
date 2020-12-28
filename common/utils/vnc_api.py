from vnc_api.vnc_api import EncapsulationPrioritiesType
from vnc_api import vnc_api


class VncApiProxy(object):

    def __init__(self, controller_nodes, logger):
        self.controller_nodes = controller_nodes
        self.logger = logger
        self._vnc_lib = None

    @property
    def vnc_lib(self):
        if self._vnc_lib is None:
            # TODO: add keystone creds
            # TODO: add ssl
            self.logger.info(f'Create VncApi client: api_servers="{self.controller_nodes}"')
            self._vnc_lib = vnc_api.VncApi(api_server_host=self.controller_nodes)
        return self._vnc_lib

    def get_encap_priorities(self):
        fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=fq_name)
        encap_obj = gr_obj.get_encapsulation_priorities()
        if not encap_obj:
            return ['', '', '']
        encaps = encap_obj.encapsulation
        encaps.extend([''] * (3 - len(encaps)))
        return encaps

    def set_encap_priorities(self, encaps):
        fq_name = ['default-global-system-config', 'default-global-vrouter-config']
        encap_obj = EncapsulationPrioritiesType(encapsulation=encaps)
        gr_obj = self.vnc_lib.global_vrouter_config_read(fq_name=fq_name)
        gr_obj.set_encapsulation_priorities(encap_obj)
        self.vnc_lib.global_vrouter_config_update(gr_obj)
