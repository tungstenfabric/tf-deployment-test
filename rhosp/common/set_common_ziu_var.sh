#!/bin/bash

source /tmp/test.env
source rhosp-environment.sh

overcloud_prov_ip_list=''
overcloud_instance_list=''
for nodes in "$CONTROLLER_NODES" "$OPENSTACK_CONTROLLER_NODES" "$AGENT_NODES"; do
    for node in $(echo $nodes | sed "s/,/ /g"); do
        cutted_node="$(echo $node | cut -d "." -f1)"
        if [[ $overcloud_prov_ip_list != *"$node"* ]]; then
            overcloud_prov_ip_list+="$node "
        fi
        if [[ $overcloud_instance_list != *"$cutted_node"* ]]; then
            overcloud_instance_list+="$cutted_node "
        fi
    done
done

echo "$(date) overcloud_prov_ip_list:  $overcloud_prov_ip_list"
echo "$(date) overcloud_instance_list: $overcloud_instance_list"
