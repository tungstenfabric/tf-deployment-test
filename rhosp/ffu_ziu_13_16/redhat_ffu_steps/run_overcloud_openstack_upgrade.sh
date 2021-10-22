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
declare -A host_pids
openstack_controller_batch=''
for host in $(echo $batch | sed 's/,/ /g'); do
    if [[ ! $host =~ 'overcloud-controller-' ]]; then
        if [ -f "success_openstack_upgrade_${host}" ]; then
            echo "node $host was already upgraded before. Skipping"
        else
            openstack overcloud upgrade run --yes \
                --stack overcloud \
                --limit $host --playbook all 2>&1 | tee openstack_overcloud_upgrade_run_${host} &
            pid=$!
            bkg_pids+=" $pid "
            host_pids[$pid]=$host
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
    if [ -f "success_openstack_upgrade_${openstack_controller_batch}" ]; then
        echo "batch $openstack_controller_batch was already upgraded before. Skipping"
    else
        openstack overcloud upgrade run --yes \
            --stack overcloud \
            --limit $openstack_controller_batch --playbook all 2>&1 | tee openstack_overcloud_upgrade_run_${openstack_controller_batch} &
        pid=$!
        bkg_pids+=" $pid "
        host_pids[$pid]=$openstack_controller_batch
    fi
fi

status=0
for p in $bkg_pids; do
    if wait $p; then
        if [ -f "success_openstack_upgrade_${host_pids[$p]}" ]; then
            echo "File success_openstack_upgrade_${host_pids[$p]} already exists. Skipping"
        else
            touch "success_openstack_upgrade_${host_pids[$p]}"
            echo "Created file success_openstack_upgrade_${host_pids[$p]}"
        fi
        echo "Sucessful openstack upgrade for ${host_pids[$p]}"
    else
        echo "Failed openstack upgrade for ${host_pids[$p]}"
        status=1
    fi
done

if [[ $status == 0 ]]; then
    echo "[$(date)] SUCCESS: Finished major overcloud upgrade for $batch"
else
    echo "[$(date)] FAILED major overcloud upgrade for $batch"
    exit 1
fi

