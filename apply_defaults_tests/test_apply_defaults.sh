#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source "$my_dir/tools/test_common.sh"

IFS=', ' read -r -a array_controller_nodes <<< "$CONTROLLER_NODES"
node=${array_controller_nodes[0]}
echo "node is $node"

encap_before_test=$(python3 /apply_defaults_tests/tools/get_encap_priority.py $node)

echo "encap_before_test is $encap_before_test"

# default_encap_priority_beauty="encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
default_encap_priority_raw='MPLSoUDP,MPLSoGRE,VXLAN'
default_encap_priority_prepared=$(python3 /apply_defaults_tests/tools/get_beauty_encap_value.py $default_encap_priority_raw)
if [[ "$encap_before_test" != "$default_encap_priority_prepared" ]] ; then
  echo "WARNING: current encap_priority is not default $default_encap_priority_prepared"
fi

new_encap_priority_raw='MPLSoGRE,VXLAN,MPLSoUDP'
new_encap_priority_prepared=$(python3 /apply_defaults_tests/tools/get_beauty_encap_value.py $new_encap_priority_raw)
if [[ "$encap_before_test" == "$new_encap_priority_prepared" ]] ; then
  new_encap_priority_raw='VXLAN,MPLSoUDP,MPLSoGRE'
fi
echo "we begining set encap_priority = $new_encap_priority_raw"
change_result=$(python3 /apply_defaults_tests/tools/change_encap_priority.py $node $new_encap_priority_raw)
echo "result of change_encap_priority is $change_result"

encap_after_change=$(python3 /apply_defaults_tests/tools/get_encap_priority.py $node)
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

encap_after_restart=$(python3 /apply_defaults_tests/tools/get_encap_priority.py $node)
echo "encap_after_restart is $encap_after_restart"

# get APPLY_DEFAULTS value
scp $SSH_OPTIONS "centos@$node:~/tf-ansible-deployer/instances.yaml" /
instances_yaml_file='/instances.yaml'
cat $instances_yaml_file
apply_defaults_value=$(python3 /apply_defaults_tests/tools/get_apply_default.py $instances_yaml_file)
echo "apply_defaults is $apply_defaults_value"

# final check
if [[ "$apply_defaults_value" == "true" ]] ; then
  if [[ "$encap_before_test" != "$encap_after_restart" ]] ; then
    echo "encap_before_test   is $encap_before_test"
    echo "encap_after_restart is $encap_after_restart"
    echo "ERROR: encap_priority was not reseted after restarting containers"
    exit 1
  fi
else
  if [[ "$encap_before_test" == "$encap_after_restart" ]] ; then
    echo "ERROR: encap_priority was reseted after restarting containers"
    exit 1
  fi
fi

echo "test_get_current_encap_value: PASSED"

exit 0