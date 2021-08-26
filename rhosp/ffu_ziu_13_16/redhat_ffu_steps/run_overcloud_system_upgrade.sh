#!/bin/bash

set -euo pipefail

#This script runs system_upgrade for the comma-separated list of nodes

if [[ -z $1 ]]; then
    echo "No arguments. Please specify the list of the nodes for upgrade"
    echo "Usage: $0 <node-1,node-2,node-3>"
    exit 1
fi

batch=$1

echo "[$(date)] Started system upgrade step for $batch"

bkg_pids=""
for host in $(echo "$batch" | sed "s/,/ /g"); do
    if [ -f "success_system_upgrade_${host}" ]; then
        echo "File success_system_upgrade_${host} already exists. Skipping"
    else 
        openstack overcloud upgrade run --yes \
            --stack overcloud \
            --tags system_upgrade \
            --limit "${host}" 2>&1 | tee -a "RHEL_upgrade_${host}" &
        bkg_pids+=" $! "
    fi
done

status=0
for p in $bkg_pids; do
    if ! wait $p; then
        status=1
    fi
done

if [[ $status == 0 ]]; then
    echo "[$(date)] Finished system upgrade step for $batch"
    for host in $(echo $batch | sed 's/,/ /g'); do
        if [ -f "success_system_upgrade_${host}" ]; then
            echo "File success_system_upgrade_${host} already exists. Skipping"
        else 
            touch "success_system_upgrade_${host}"
            echo "Created file success_system_upgrade_${host}"
        fi
    done
else
    echo "[$(date)] Failed in system upgrade step for $batch"
    exit 1
fi
