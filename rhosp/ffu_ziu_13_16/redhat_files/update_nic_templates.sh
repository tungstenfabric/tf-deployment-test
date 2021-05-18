#!/bin/bash -eux
cd ~
STACK_NAME="overcloud"
ROLES_DATA="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"
NETWORK_DATA="$(pwd)/tripleo-heat-templates/network_data.yaml"
NIC_CONFIG_LINES=$(openstack stack environment show $STACK_NAME | grep "::Net::SoftwareConfig" | sed -E 's/ *OS::TripleO::// ; s/::Net::SoftwareConfig:// ; s/ http.*overcloud/ tripleo-heat-templates/')
echo "$NIC_CONFIG_LINES" | while read LINE; do
    ROLE=$(echo "$LINE" | awk '{print $1;}')
    NIC_CONFIG=$(echo "$LINE" | awk '{print $2;}')

    if [ -f "$NIC_CONFIG" ] && grep -q "name: $ROLE" $ROLES_DATA ; then
        echo "Updating template for $ROLE role."
        python3 tripleo-heat-templates/tools/merge-new-params-nic-config-script.py \
            --tht-dir tripleo-heat-templates \
            --roles-data $ROLES_DATA \
            --network-data $NETWORK_DATA \
            --role-name "$ROLE" \
            --discard-comments yes \
            --template "$NIC_CONFIG"
    else
        echo "No NIC template detected for $ROLE role. Skipping $ROLE role."
    fi
done
