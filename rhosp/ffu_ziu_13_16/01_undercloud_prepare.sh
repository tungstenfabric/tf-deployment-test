#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

#Collect information about undercloud before upgrade
[[ -d before_upgrade.data ]] || mkdir before_upgrade.data
cd before_upgrade.data
uname -a >undercloud_uname.output
rpm -qa > undercloud_installed_packages.txt
cp /etc/os-release undercloud_os-release
docker ps -a >undercloud_docker_ps.output

#Collect overcloud node information before update
node_admin_username=${NODE_ADMIN_USERNAME:-'heat-admin'}
for node in overcloud-controller-0 overcloud-contrailcontroller-0 overcloud-novacompute-0; do
    ip=$(openstack server list --name $node -c Networks -f value | cut -d '=' -f2)
    [[ -n "$ip" ]]
    ssh $node_admin_username@$ip "uname -a" >${node}_uname.output
    ssh $node_admin_username@$ip "rpm -qa" >${node}_installed_packages.txt
    ssh $node_admin_username@$ip "cat /etc/os-release" >${node}_os-release
    ssh $node_admin_username@$ip "sudo docker ps -a" >${node}_docker_ps.output
done    

cd ~
ansible-playbook -c local -i localhost, $my_dir/redhat_files/playbook-ssh.yaml
ansible-playbook -c local -i localhost, $my_dir/redhat_files/playbook-nics.yaml
ansible-playbook -c local -i localhost, $my_dir/redhat_files/playbook-nics-vlans.yaml

#Fix for 7.8. It must to be upgraded to 7.9 for leapp upgrade
sudo yum update -y

echo "Perform reboot: sudo reboot"

echo $(date) "------------------ FINISHED: $0 ------------------"
