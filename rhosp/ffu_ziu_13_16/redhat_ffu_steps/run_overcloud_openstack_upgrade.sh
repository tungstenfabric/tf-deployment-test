#!/bin/bash

set -euo pipefail
#This script runs openstack overcloud upgrade run for the comma-separated list of nodes

if [[ -z $1 ]]; then
    echo "No arguments. Please specify the list of the nodes for upgrade"
    echo "Usage: $0 <node-1,node-2,node-3>"
    exit 1
fi

limit=$1

echo "[$(date)] Running major upgrade for hosts: $limit"

openstack overcloud upgrade run --yes \
    --stack overcloud \
    --limit $limit --playbook all 2>&1 | tee openstack_overcloud_upgrade_run_${limit}
echo "[$(date)] Finished major upgrade for hosts: $limit"

