#!/usr/bin/env python3
from vnc_api import vnc_api
from vnc_api.vnc_api import EncapsulationPrioritiesType
import sys


# TODO: add supproting SSL
def set_encap_priority(new_encap, hostname, fq_name):
    vnc_lib = vnc_api.VncApi(api_server_host=hostname)
    gr_obj = vnc_lib.global_vrouter_config_read(fq_name=fq_name)
    encap_obj = EncapsulationPrioritiesType(encapsulation=new_encap)
    gr_obj.set_encapsulation_priorities(encap_obj)
    vnc_lib.global_vrouter_config_update(gr_obj)


my_hostname = sys.argv[1]
encaps = sys.argv[2].split(",")
my_fq_name = ['default-global-system-config', 'default-global-vrouter-config']

set_encap_priority(encaps, my_hostname, my_fq_name)
