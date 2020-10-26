#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source /root/.tf/stack.env

export CONTROLLER_NODES="${CONTROLLER_NODES}"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}
export SSH_USER=${SSH_USER:-"centos"}

IFS=', ' read -r -a array_controller_nodes <<< "$CONTROLLER_NODES"
node=${array_controller_nodes[0]}
echo "node is $node"

# get APPLY_DEFAULTS value
scp $SSH_OPTIONS "centos@$node:~/tf-ansible-deployer/instances.yaml" / 2>/dev/null
instances_yaml_file='/instances.yaml'
echo "cat $instances_yaml_file"
cat $instances_yaml_file
apply_defaults_value=$(python3 $my_dir/tools/get_apply_default.py $instances_yaml_file)
echo "apply_defaults is $apply_defaults_value"

encap_before_test=$(python3 $my_dir/tools/get_encap_priority.py $node)
echo "encap_before_test is $encap_before_test"

default_encap_priority='MPLSoUDP, MPLSoGRE,VXLAN'
if [[ "$encap_before_test" != "$default_encap_priority_prepared" ]] ; then
  echo "ERROR: current encap_priority is not default $default_encap_priority_prepared"
  exit 1
fi

new_encap_priority='VXLAN,MPLSoUDP,MPLSoGRE'

echo "we begining set encap_priority = $new_encap_priority"
change_result=$(python3 $my_dir/tools/change_encap_priority.py $node $new_encap_priority)
echo "result of change_encap_priority is $change_result"

encap_after_change=$(python3 $my_dir/tools/get_encap_priority.py $node)
echo "encap_after_change is $encap_after_change"

if [[ "$encap_before_test" == "$encap_after_change" ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  exit 1
fi

# TODO: reboot only contrail containers
for machine in ${array_controller_nodes[*]} ; do
  ssh $SSH_OPTIONS "centos@$machine" "sudo docker restart \$(sudo docker ps -q | grep -v ^$HOSTNAME) &>/dev/null" 2>/dev/null &
done
wait
sleep 60

encap_after_restart=$(python3 $my_dir/tools/get_encap_priority.py $node)
echo "encap_after_restart is $encap_after_restart"

# final check
if [[ "$apply_defaults_value" == true ]] ; then
  if [[ "$encap_before_test" != "$encap_after_restart" ]] ; then
    echo "ERROR: encap_priority was not reseted after restarting containers"
    exit 1
  fi
else
  if [[ "$encap_before_test" == "$encap_after_restart" ]] ; then
    echo "ERROR: encap_priority was reseted after restarting containers"
    exit 1
  fi
fi

echo "test_apply_defaults: PASSED"

exit 0