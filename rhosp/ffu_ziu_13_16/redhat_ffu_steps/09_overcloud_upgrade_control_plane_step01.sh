#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source $my_dir/../../common/functions.sh
source stackrc
source rhosp-environment.sh

upgrade_plan=${1:-'overcloud_controlplane_upgrade_plan'}

if [[ ! -f $upgrade_plan ]]; then
    echo "File $upgrade_plan not found. Please prepare overcloud_controlplane_upgrade_plan. Exit"
    exit 1
fi

#First line of upgrade_plan contain the bootstrap_node
batch=$(head -1 $upgrade_plan)

if [ ! -f .ceph_ran_$batch ]; then
    echo "[$(date)] Started ceph systemd units migration run for $batch"
    openstack overcloud external-upgrade run --yes \
        --stack overcloud \
        --tags ceph_systemd \
        -e ceph_ansible_limit=$batch 2>&1 && touch ".ceph_ran_$batch"
    echo "[$(date)] Finished ceph systemd units migration run for $batch"
fi

$my_dir/run_overcloud_system_upgrade.sh $batch

if [ ! -f .system_upgrade_transfer_data ]; then
     echo "[$(date)] Started upgrade transfer data for $batch"
     openstack overcloud external-upgrade run --yes \
         --stack overcloud \
         --tags system_upgrade_transfer_data 2>&1 && touch .system_upgrade_transfer_data
     echo "[$(date)] Finished upgrade transfer data for $batch"
fi

if [ ! -f nova_hybrid_state ]; then
     echo "[$(date)] Setting up hybrid state for computes"
     openstack overcloud upgrade run --yes \
         --stack overcloud \
         --playbook upgrade_steps_playbook.yaml \
         --tags nova_hybrid_state --limit all 2>&1 && touch .nova_hybrid_state
     echo "[$(date)] Finished setting up hybrid state for computes"
fi

$my_dir/run_overcloud_openstack_upgrade.sh $batch

echo $(date) "------------------ FINISHED: $0 ------------------"

