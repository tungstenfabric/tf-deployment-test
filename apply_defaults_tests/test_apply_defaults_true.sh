#!/bin/bash -x

# i hope this test working (21.10.2020)

for machine in $CONTROLLER_NODES ; do
  node=machine
done

encap_before_test=$(python3 get_encap_priority.py $node)

default_encap_priority="encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
if [[ $encap_before_test != $default_encap_priority ]] ; then
  echo "ERROR: encap_priority is not default"
  return 1
fi

new_encap_priority="['MPLSoGRE', 'VXLAN', 'MPLSoUDP']"
echo $(python3 change_encap_priority.py $node $new_encap_priority)

# check changes
encap_after_change=$(python3 get_encap_priority.py $node)
if [[ $encap_before_test == $encap_after_change ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  return 1
fi

# restarting all containers on CONTROLLER_NODES
for machine in $CONTROLLER_NODES ; do
  ssh $SSH_OPTIONS $machine 'sudo docker restart $(sudo docker ps -q)'
done
# need waiting ?

encap_after_restart=$(python3 get_encap_priority.py $node)
if [[ $encap_before_test != $encap_after_restart ]] ; then
  echo "ERROR: encap_priority was not reseted after restarting containers"
  return 1
fi

echo "Test apply_default=true: PASSED"
return 0
