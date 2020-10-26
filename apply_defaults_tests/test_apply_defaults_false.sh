#!/bin/bash -ex

# this version tests is not updated (26.10.2020)


encap_before_test=$($my_dir/get_encap_priority.py $HOSTNAME)

default_encap_priority="encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
if [[ $encap_before_test != $default_encap_priority ]] ; then
  echo "ERROR: encap_priority is not default"
  exit 1
fi

new_encap_priority="['MPLSoGRE', 'VXLAN', 'MPLSoUDP']"
echo $(python3 change_encap_priority.py $HOSTNAME $new_encap_priority)

# check changes
encap_after_change=$($my_dir/get_encap_priority.py $HOSTNAME)
if [[ $encap_before_test == $encap_after_change ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  exit 1
fi

# restarting all containers on CONTROLLER_NODES
for machine in $CONTROLLER_NODES ; do
  ssh $SSH_OPTIONS $machine 'sudo docker restart $(sudo docker ps -q)'
done
# need waiting ?

encap_after_restart=$($my_dir/get_encap_priority.py $HOSTNAME)
if [[ $encap_after_change != $encap_after_restart ]] ; then
  echo "ERROR: encap_priority was reseted after restarting containers"
  exit 1
fi

echo "Test apply_default=true: PASSED"
exit 0
