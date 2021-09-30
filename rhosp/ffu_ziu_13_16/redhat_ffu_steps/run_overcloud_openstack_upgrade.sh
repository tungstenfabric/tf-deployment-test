#!/bin/bash

set -euo pipefail
#This script runs parallel openstack overcloud upgrade run for the comma-separated list of nodes

if [[ -z $1 ]]; then
    echo "No arguments. Please specify the list of the nodes for upgrade"
    echo "Usage: $0 <node-1,node-2,node-3>"
    exit 1
fi

batch=$1

echo "[$(date)] Running major upgrade for hosts: $batch"

#Running contrail nodes in parallel with openstack controllers 
bkg_pids=""
openstack_controller_batch=''
for host in $(echo $batch | sed 's/,/ /g'); do
    if [[ $host =~ 'contrail' ]]; then
        if [ -f "success_openstack_upgrade_${host}" ]; then
            echo "node $host was already upgraded before. Skipping"
        else 
            openstack overcloud upgrade run --yes \
                --stack overcloud \
                --limit $host --playbook all 2>&1 | tee openstack_overcloud_upgrade_run_${host} &
            bkg_pids+=" $! "
        fi
    else 
        if [[ -z $openstack_controller_batch ]]; then
            openstack_controller_batch+="$host"
        else 
            openstack_controller_batch+=",$host"
        fi
    fi
done

if [[ -n "$openstack_controller_batch" ]] ; then
    openstack overcloud upgrade run --yes \
        --stack overcloud \
        --limit $openstack_controller_batch --playbook all 2>&1 | tee openstack_overcloud_upgrade_run_${openstack_controller_batch} &
    bkg_pids+=" $! "
fi

status=0
for p in $bkg_pids; do
    if ! wait $p; then
        status=1
    fi
done

if [[ $status == 0 ]]; then
    echo "[$(date)] Finished major overcloud upgrade for $batch"
    for host in $(echo $batch | sed 's/,/ /g'); do
        if [ -f "success_openstack_upgrade_${host}" ]; then
            echo "File success_openstack_upgrade_${host} already exists. Skipping"
        else 
            touch "success_openstack_upgrade_${host}"
            echo "Created file success_openstack_upgrade_${host}"
        fi
    done
else
    echo "[$(date)] Failed major overcloud upgrade for $batch"
    exit 1
fi

