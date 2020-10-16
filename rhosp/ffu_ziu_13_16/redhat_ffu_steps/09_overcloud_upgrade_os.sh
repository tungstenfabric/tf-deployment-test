#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

#17.2. Upgrading Controller nodes
ctrl_ip=$(openstack server list --name overcloud-controller-0 -c Networks -f value | cut -d '=' -f2)
[[ -n "$ctrl_ip" ]]

node_admin_username=${NODE_ADMIN_USERNAME:-'heat-admin'}
pcs_bootstrap_node=$(ssh $node_admin_username@$ctrl_ip "sudo hiera -c /etc/puppet/hiera.yaml pacemaker_short_bootstrap_node_name")
[[ -n "$pcs_bootstrap_node" ]]

openstack overcloud external-upgrade run --stack overcloud --tags ceph_systemd \
  -e ceph_ansible_limit=$pcs_bootstrap_node
openstack overcloud upgrade run --stack overcloud --tags system_upgrade --limit $pcs_bootstrap_node
openstack overcloud external-upgrade run --stack overcloud --tags system_upgrade_transfer_data
openstack overcloud upgrade run --stack overcloud --playbook upgrade_steps_playbook.yaml --tags nova_hybrid_state --limit all
openstack overcloud upgrade run --stack overcloud --limit $pcs_bootstrap_node

upgraded_controllers=$pcs_bootstrap_node
for node in $(openstack server list --name overcloud-controller -c Name -f value | grep -v "$pcs_bootstrap_node" ) ; do
  openstack overcloud external-upgrade run --stack overcloud --tags ceph_systemd \
    -e ceph_ansible_limit=$node
  openstack overcloud upgrade run --stack overcloud --tags system_upgrade --limit $node
  upgraded_controllers+=",$node"
  openstack overcloud upgrade run --stack overcloud --limit $upgraded_controllers
done

echo $(date) "------------------ FINISHED: $0 ------------------"
