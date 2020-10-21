#!/bin/bash -x

# this version tests is not updated (21.10.2020)

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

# deployment
export APPLY_DEFAULTS=false
sudo yum install -y git
git clone http://github.com/tungstenfabric/tf-devstack
"$my_dir/tf-devstack/ansible/run.sh"

# get CONTROLLER_NODES and other env from /.tf/stack.env
source "$my_dir/env_profile.sh"

pip3 install contrail-api-client future six

my_fq_name="['default-global-system-config', 'default-global-vrouter-config']"
encap_before_test=$($my_dir/get_encap_priority.py $HOSTNAME $my_fq_name)

default_encap_priority="encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
if [[ $encap_before_test != $default_encap_priority ]] ; then
  echo "ERROR: encap_priority is not default"
  return 1
fi

new_encap_priority="['MPLSoGRE', 'VXLAN', 'MPLSoUDP']"
echo $(python3 change_encap_priority.py $HOSTNAME $my_fq_name $new_encap_priority)

# check changes
encap_after_change=$($my_dir/get_encap_priority.py $HOSTNAME $my_fq_name)
if [[ $encap_before_test == $encap_after_change ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  return 1
fi

# restarting all containers on CONTROLLER_NODES
for machine in $CONTROLLER_NODES ; do
  ssh $SSH_OPTIONS $machine 'sudo docker restart $(sudo docker ps -q)'
done
# need waiting ?

encap_after_restart=$($my_dir/get_encap_priority.py $HOSTNAME $my_fq_name)
if [[ $encap_after_change != $encap_after_restart ]] ; then
  echo "ERROR: encap_priority was reseted after restarting containers"
  return 1
fi

echo "Test apply_default=true: PASSED"
return 0
