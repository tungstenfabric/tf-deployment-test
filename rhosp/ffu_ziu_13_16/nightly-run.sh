#!/bin/bash -eu

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

cd
source nightly-env.sh
source $my_dir/../common/functions.sh

checkForVariable SSH_USER
checkForVariable mgmt_ip
checkForVariable ssh_private_key
checkForVariable undercloud_public_host
checkForVariable undercloud_admin_host
checkForVariable NODE_ADMIN_USERNAME
checkForVariable CONTAINER_REGISTRY_FFU
checkForVariable CONTRAIL_CONTAINER_TAG_FFU
checkForVariable OPENSTACK_CONTAINER_REGISTRY_FFU

cd

echo "Copiyng ffu/* to undercloud node"
scp -r ./ffu $SSH_USER@$mgmt_ip:./
scp -r nightly-env.sh $SSH_USER@$mgmt_ip:./rhosp-environment.sh

echo Preparing for undercloud RHEL upgrade

run_ssh_undercloud 'ffu/00-nightly-lab-fix.sh'

echo "Preparing for undercloud RHEL upgrade"
run_ssh_undercloud './ffu/01_undercloud_prepare.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/02_undercloud_upgrade_rhel_step1.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/03_undercloud_upgrade_rhel_step2.sh'
reboot_and_wait_undercloud

run_ssh_undercloud './ffu/04_undercloud_upgrade_tripleo.sh'

######################################################
#                  OVERCLOUD                         #
######################################################
run_ssh_undercloud './ffu/06_overcloud_prepare.sh'
run_ssh_undercloud './ffu/07_overcloud_prepare_templates.sh'
run_ssh_undercloud './ffu/08_overcloud_upgrade_prepare.sh'
run_ssh_undercloud './ffu/09_overcloud_upgrade_os.sh'
run_ssh_undercloud './ffu/10_overcloud_upgrade_contrail_ctrl.sh'
run_ssh_undercloud './ffu/11_overcloud_upgrade_compute.sh'
run_ssh_undercloud './ffu/12_overcloud_upgrade_converge.sh'
run_ssh_undercloud './ffu/13_collect_information.sh'
