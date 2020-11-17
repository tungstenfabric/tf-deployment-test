#!/bin/bash -eu

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

cd
source $my_dir/../common/functions.sh

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
checkForVariable RHEL_LOCAL_MIRROR_FFU

#Setting FFU parameters
rm /tmp/rhosp-environment.sh || true
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
add_variable /tmp/rhosp-environment.sh RHEL_LOCAL_MIRROR_FFU $RHEL_LOCAL_MIRROR_FFU
add_variable /tmp/rhosp-environment.sh undercloud_admin_host $undercloud_admin_host
add_variable /tmp/rhosp-environment.sh undercloud_public_host $undercloud_public_host

cd
#Updating rhosp-environment.sh
ssh $SSH_USER@$mgmt_ip cp rhosp-environment.sh rhosp-environment-rhosp13-backup.sh
scp -r /tmp/rhosp-environment.sh $SSH_USER@$mgmt_ip:
echo "Copying tf-deployment-test to undercloud node"
scp -r $my_dir/../../* $SSH_USER@$mgmt_ip:tf-deployment-test

echo $(date) START: Start upgrading undercloud | tee -a run.log
echo "Preparing for undercloud RHEL upgrade"
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/01_undercloud_prepare.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/02_undercloud_upgrade_rhel_step1.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/03_undercloud_upgrade_rhel_step2.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/04_undercloud_upgrade_tripleo.sh'

echo $(date) Preparing contrail images | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/tf_specific/05_contrail_images_prepare.sh'

######################################################
#                  OVERCLOUD                         #
######################################################
echo $(date) Preparing overcloud nodes | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/06_overcloud_prepare.sh'
echo $(date) Preparing heat template | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/07_overcloud_prepare_templates.sh'
echo $(date) Start overcloud upgrade prepare | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/08_overcloud_upgrade_prepare.sh'
echo $(date) Start overcloud controller update | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/09_overcloud_upgrade_os.sh'
echo $(date) Start overcloud contrail-controller update | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/10_overcloud_upgrade_contrail_ctrl.sh'
echo $(date) Start overcloud compute update | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/11_overcloud_upgrade_compute.sh'
echo $(date) Start overcloud upgrade converge | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/12_overcloud_upgrade_converge.sh'
echo $(date) FINISH: Collecting the information | tee -a run.log
run_ssh_undercloud './tf-deployment-test/rhosp/ffu_ziu_13_16/redhat_ffu_steps/13_collect_information.sh'

