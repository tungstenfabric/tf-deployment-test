#!/bin/bash

#This script runs system_upgrade for the comma-separated list of nodes
# use separate steps for system_upgrade_prepare + system_upgrade_run
# instead of united system_upgrade to allow some hack for vhost0

if [[ -z $1 ]]; then
    echo "No arguments. Please specify the list of the nodes for upgrade"
    echo "Usage: $0 <node-1,node-2,node-3>"
    exit 1
fi

batch=$1

echo "[$(date)] Started system upgrade prepare step for $batch"

bkg_pids=""
for host in $(echo "$batch" | sed "s/,/ /g"); do
    openstack overcloud upgrade run --yes --stack overcloud --tags system_upgrade_prepare --limit $host | tee -a "RHEL_system_upgrade_prepare_${host}" &
    bkg_pids+=" $! "
done

status=0
for p in $bkg_pids; do
    if ! wait $p; then
        status=1
    fi
done

if [[ $status == 0 ]]; then
    echo "[$(date)] Finished system upgrade prepare step for $batch"
else
    echo "[$(date)] Failed in system upgrade prepare step for $batch"
    exit 1
fi
