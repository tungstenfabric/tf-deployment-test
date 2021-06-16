#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

upgrade_plan=${1:-'overcloud_compute_upgrade_plan'}

if [[ ! -f $upgrade_plan ]]; then
    echo "File $upgrade_plan not found. Please prepare overcloud_compute_upgrade_plan. Exit"
    exit 1
fi

#19.3. Upgrading Compute nodes
while IFS= read -r line; do
    $my_dir/../tf_specific/run_overcloud_system_upgrade_prepare.sh $line
    $my_dir/../tf_specific/run_overcloud_system_upgrade_run.sh $line
    bkg_pids=""
    for host in $(echo $line | sed 's/,/ /g'); do
        $my_dir/run_overcloud_openstack_upgrade.sh $host &
        bkg_pids+=" $! "
    done

    status=0
    for p in $bkg_pids; do
        if ! wait $p; then
            status=1
        fi
    done

    if [[ $status == 0 ]]; then
        echo "[$(date)] Finished openstack upgrade for $line"
    else
        echo "[$(date)] Failed openstack upgrade for $line"
        exit 1
    fi

done <"$upgrade_plan"


echo $(date) "------------------ FINISHED: $0 ------------------"
