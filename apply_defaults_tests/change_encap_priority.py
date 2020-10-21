#!/usr/bin/env python3
from vnc_api import vnc_api
from vnc_api.vnc_api import EncapsulationPrioritiesType
import sys


# TODO: add supproting SSL
def change_encap_priority(new_encap, hostname, fq_name):
    try:
        vnc_lib = vnc_api.VncApi(api_server_host=hostname)
        gr_obj = vnc_lib.global_vrouter_config_read(fq_name=fq_name)
        encap_obj = EncapsulationPrioritiesType(encapsulation=new_encap)
        gr_obj.set_encapsulation_priorities(encap_obj)
        vnc_lib.global_vrouter_config_update(gr_obj)
        return True
    except Exception as e:
        return e


my_hostname = sys.argv[1]
encaps = sys.argv[2]
my_fq_name = ['default-global-system-config', 'default-global-vrouter-config']

result = change_encap_priority(encaps, my_hostname, my_fq_name)
print(result)
