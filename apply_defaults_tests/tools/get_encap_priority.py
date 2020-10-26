#!/usr/bin/env python3
import sys
from vnc_api import vnc_api

# TODO: add supproting SSL
my_hostname = sys.argv[1]
# my_fq_name type list
my_fq_name = ['default-global-system-config', 'default-global-vrouter-config']
vnc_lib = vnc_api.VncApi(api_server_host=my_hostname)
gr_obj = vnc_lib.global_vrouter_config_read(fq_name=my_fq_name)
encap_priority = gr_obj.get_encapsulation_priorities()
print(encap_priority[17:-1].replace("'", "").replace(" ", ""))
# before "encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
# after "MPLSoUDP,MPLSoGRE,VXLAN"
