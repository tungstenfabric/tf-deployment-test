#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

if [ ! -e tripleo-heat-templates.rhosp13 ] ; then
  mv tripleo-heat-templates tripleo-heat-templates.rhosp13
fi

rm -rf tripleo-heat-templates
cp -r /usr/share/openstack-tripleo-heat-templates tripleo-heat-templates
rm -rf tf-tripleo-heat-templates
git clone https://review.opencontrail.org/tungstenfabric/tf-tripleo-heat-templates -b stable/train
cp -r tf-tripleo-heat-templates/* tripleo-heat-templates/

#8.1. CREATING AN UPGRADES ENVIRONMENT FILE
cp $my_dir/../redhat_files/upgrades-environment.yaml tripleo-heat-templates/
#this file was removed from doc
#cp $my_dir/../redhat_files/workaround.yaml tripleo-heat-templates/

#9.3. Configuring access to the undercloud registry
container_node_name=$(sudo hiera container_image_prepare_node_names | sed 's/[]["]//g')
container_node_ip=$(sudo hiera container_image_prepare_node_ips | sed 's/[]["]//g')
cat <<EOF >> contrail-parameters.yaml
  DockerInsecureRegistryAddress:
    - ${container_node_name}:8787
    - ${container_node_ip}:8787
EOF

#13.1. Updating network interface templates
$my_dir/../redhat_files/update_nic_templates.sh

role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"

# Remove ContrailControlOnly role otherwise TripleO includes tasks
# from external_upgrade_tasks for this role that has empty tripleo_delegate_to
# in test configuration and that leads to fail with error
# "Fail if tripleo_delegate_to is undefined" for undercloud node
sed -i '/ContrailControlOnly/,/ContrailDpdk/{//!d}' $role_file

echo $(date) "------------------ FINISHED: $0 ------------------"
