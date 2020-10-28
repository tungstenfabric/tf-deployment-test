#!/bin/bash -ex

sudo docker ps

echo "low info"

cont_name="tf-deployment-test-apply"
if sudo docker ps -q -f name=$cont_name ; then
  test_container_id="$(sudo docker ps -q -f name=$cont_name)"
  echo "test_container_id is $test_container_id"
  echo "containers for reboot"
  sudo docker ps -q | grep -v ^$test_container_id
else
  echo "Pochemu-to ne nashli container $cont_name"
fi


if [[ -f ".tf/stack.env" ]] ; then
  set -a
  source ".tf/stack.env"
  set +a
fi

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}
export SSH_USER=${SSH_USER:-"centos"}

IFS=', ' read -r -a array_controller_nodes <<< "$CONTROLLER_NODES"
node=${array_controller_nodes[0]}
echo "node is $node"

if cat tf-ansible-deployer/instances.yaml | grep 'APPLY_DEFAULTS: "false"' ; then
  apply_defaults_value="false"
else
  apply_defaults_value="true"
fi
echo "apply_defaults is $apply_defaults_value"

# need: python3 -m pip install --no-compile "contrail-api-client==2005" "future==0.18.2" "six==1.15.0" "requests==2.24.0"
encap_before_test=$(python3 $my_dir/tools/get_encap_priority.py $node)
echo "encap_before_test is $encap_before_test"

default_encap_priority='MPLSoUDP,MPLSoGRE,VXLAN'
if [[ "$encap_before_test" != "$default_encap_priority" ]] ; then
  echo "ERROR: current encap_priority is not default $default_encap_priority"
  exit 1
fi

new_encap_priority='VXLAN,MPLSoUDP,MPLSoGRE'
echo "we begining set encap_priority = $new_encap_priority"
$(python3 $my_dir/tools/set_encap_priority.py $node $new_encap_priority)

encap_after_change=$(python3 $my_dir/tools/get_encap_priority.py $node)
echo "encap_after_change is $encap_after_change"

if [[ "$encap_before_test" == "$encap_after_change" ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  exit 1
fi

# TODO: reboot only contrail containers
for machine in ${array_controller_nodes[*]} ; do
  ssh $SSH_OPTIONS "$SSH_USER@$machine" "sudo docker restart \$(sudo docker ps -q | grep -v ^$test_container_id) &>/dev/null" 2>/dev/null &
done
wait
sleep 60
# infinity process

#encap_after_restart=$(python3 $my_dir/tools/get_encap_priority.py $node)
#echo "encap_after_restart is $encap_after_restart"
#
## final check
#if [[ "$apply_defaults_value" == true ]] ; then
#  if [[ "$default_encap_priority" != "$encap_after_restart" ]] ; then
#    echo "ERROR: encap_priority was not reseted after restarting containers"
#    exit 1
#  fi
#else
#  if [[ "$encap_before_test" == "$encap_after_restart" ]] ; then
#    echo "ERROR: encap_priority was reseted after restarting containers"
#    exit 1
#  fi
#fi

echo "$my_file: PASSED"

exit 0