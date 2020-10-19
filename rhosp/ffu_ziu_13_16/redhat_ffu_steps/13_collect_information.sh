#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

#Collect information about undercloud after upgrade
[[ -d after_upgrade.data ]] || mkdir after_upgrade.data
cd after_upgrade.data
uname -a >undercloud_uname.output
rpm -qa > undercloud_installed_packages.txt
cp /etc/os-release undercloud_os-release
podman ps -a >undercloud_podman_ps.output

#Collect overcloud node information after upgrade
node_admin_username=${NODE_ADMIN_USERNAME:-'heat-admin'}
for node in overcloud-controller-0 overcloud-contrailcontroller-0 overcloud-novacompute-0; do
    ip=$(openstack server list --name $node -c Networks -f value | cut -d '=' -f2)
    [[ -n "$ip" ]]
    ssh $node_admin_username@$ip "uname -a" >${node}_uname.output
    ssh $node_admin_username@$ip "rpm -qa" >${node}_installed_packages.txt
    ssh $node_admin_username@$ip "cat /etc/os-release" >${node}_os-release
    ssh $node_admin_username@$ip "sudo podman ps -a" >${node}_podman_ps.output
done    

echo $(date) "------------------ FINISHED: $0 ------------------"
