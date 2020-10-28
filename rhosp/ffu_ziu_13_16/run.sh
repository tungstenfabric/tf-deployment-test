#!/bin/bash -eu

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

cd
source rhosp-environment.sh
source $my_dir/functions.sh


#Red Hat Registration case
#checkForVariable RHEL_USER
#checkForVariable RHEL_PASSWORD
#checkForVariable RHEL_POOL_ID

checkForVariable SSH_USER
checkForVariable mgmt_ip
checkForVariable ssh_private_key
checkForVariable NODE_ADMIN_USERNAME
checkForVariable CONTAINER_REGISTRY_FFU
checkForVariable CONTRAIL_CONTAINER_TAG_FFU
checkForVariable OPENSTACK_CONTAINER_REGISTRY_FFU

#Setting FFU parameters 
rm /tmp/rhosp-environment.sh
scp $SSH_USER@$mgmt_ip:rhosp-environment.sh /tmp/

#Adding FFU and RHOSP16 variables
undercloud_local_ip=$(grep -o "prov_ip=.*" ~/rhosp-environment.sh | cut -d '=' -f 2 | tr -d '"')

undercloud_public_host=$(echo $undercloud_local_ip | sed s/1$/2/)
undercloud_admin_host=$(echo $undercloud_local_ip | sed s/1$/3/)

add_variable /tmp/rhosp-environment.sh SSH_USER $SSH_USER
add_variable /tmp/rhosp-environment.sh mgmt_ip $mgmt_ip
add_variable /tmp/rhosp-environment.sh ssh_private_key $ssh_private_key
add_variable /tmp/rhosp-environment.sh NODE_ADMIN_USERNAME $NODE_ADMIN_USERNAME
add_variable /tmp/rhosp-environment.sh CONTAINER_REGISTRY_FFU $CONTAINER_REGISTRY_FFU
add_variable /tmp/rhosp-environment.sh CONTRAIL_CONTAINER_TAG_FFU $CONTRAIL_CONTAINER_TAG_FFU
add_variable /tmp/rhosp-environment.sh OPENSTACK_CONTAINER_REGISTRY_FFU $OPENSTACK_CONTAINER_REGISTRY_FFU
add_variable /tmp/rhosp-environment.sh undercloud_admin_host $undercloud_admin_host
add_variable /tmp/rhosp-environment.sh undercloud_public_host $undercloud_public_host

cd
echo "Copiyng ffu/* to undercloud node"
scp -r ./rhosp-environment.sh $SSH_USER@$mgmt_ip:
scp -r $my_dir $SSH_USER@$mgmt_ip:ffu

echo "Preparing for undercloud RHEL upgrade"
run_ssh_undercloud './ffu/redhat_ffu_steps/01_undercloud_prepare.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/redhat_ffu_steps/02_undercloud_upgrade_rhel_step1.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/redhat_ffu_steps/03_undercloud_upgrade_rhel_step2.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/redhat_ffu_steps/04_undercloud_upgrade_tripleo.sh'
run_ssh_undercloud './ffu/tf_specific/05_contrail_images_prepare.sh'

######################################################
#                  OVERCLOUD                         #
######################################################
run_ssh_undercloud './ffu/redhat_ffu_steps/06_overcloud_prepare.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/07_overcloud_prepare_templates.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/08_overcloud_upgrade_prepare.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/09_overcloud_upgrade_os.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/10_overcloud_upgrade_contrail_ctrl.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/11_overcloud_upgrade_compute.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/12_overcloud_upgrade_converge.sh'
run_ssh_undercloud './ffu/redhat_ffu_steps/13_collect_information.sh'

