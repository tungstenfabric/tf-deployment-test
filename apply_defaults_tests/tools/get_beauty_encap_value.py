#!/usr/bin/env python3
import sys

# expected input -> 'MPLSoUDP,MPLSoGRE,VXLAN'

encaps_input = sys.argv[1]
array_encaps = encaps_input.split(",")
encaps_output = f"encapsulation = {array_encaps}"
print(encaps_output)
