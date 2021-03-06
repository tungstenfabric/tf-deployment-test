#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

if [ ! -e tripleo-heat-templates.rhosp13 ] ; then
  mv tripleo-heat-templates tripleo-heat-templates.rhosp13
  mv contrail-parameters.yaml contrail-parameters.yaml.rhosp13
  mv misc_opts.yaml misc_opts.yaml.rhosp13
fi

#rm -rf tripleo-heat-templates
#cp -r /usr/share/openstack-tripleo-heat-templates tripleo-heat-templates
#rm -rf tf-tripleo-heat-templates
#git clone https://github.com/tungstenfabric/tf-tripleo-heat-templates.git -b stable/train
#cp -r tf-tripleo-heat-templates/* tripleo-heat-templates/

#Using deployment framework for getting appropriate heat teamplates for RHOSP16
sed -i s/RHOSP_VERSION=\"rhosp13\"/RHOSP_VERSION=\"rhosp16\"/ rhosp-environment.sh || true
sed -i s/OPENSTACK_VERSION=\"queens\"/OPENSTACK_VERSION=\"train\"/ rhosp-environment.sh || true
if ! grep -q -E "CONTRAIL_CONTAINER_TAG=.*" rhosp-environment.sh; then
    echo "export CONTRAIL_CONTAINER_TAG=\"${CONTRAIL_CONTAINER_TAG_FFU}\"" >> rhosp-environment.sh
fi

~/tf-devstack/rhosp/overcloud/04_prepare_heat_templates.sh

#Tuning misc_opts.sh
sed -E -i "s|ContrailRegistry: '(.*)/.*'$|ContrailRegistry: '\1'|" misc_opts.yaml || true
sed -i "s/AdminPassword:.*/AdminPassword: 'c0ntrail123'/" misc_opts.yaml || true
if ! grep -q tripleo_delegate_to misc_opts.yaml; then
    echo "  tripleo_delegate_to: undercloud" >> misc_opts.yaml
fi

#8.1. CREATING AN UPGRADES ENVIRONMENT FILE
cat $my_dir/../redhat_files/upgrades-environment.yaml.template | envsubst > $my_dir/../redhat_files/upgrades-environment.yaml
cp $my_dir/../redhat_files/upgrades-environment.yaml tripleo-heat-templates/
#this file was removed from doc
#cp $my_dir/../redhat_files/workaround.yaml tripleo-heat-templates/

##9.3. Configuring access to the undercloud registry
#container_node_name=$(sudo hiera container_image_prepare_node_names | sed 's/[]["]//g')
#container_node_ip=$(sudo hiera container_image_prepare_node_ips | sed 's/[]["]//g')
#cat <<EOF >> misc_opts.yaml
#  DockerInsecureRegistryAddress:
#    - ${container_node_name}:8787
#    - ${container_node_ip}:8787
#EOF

#14.1. Updating network interface templates
$my_dir/../redhat_files/update_nic_templates.sh

role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"

# Remove ContrailControlOnly role otherwise TripleO includes tasks
# from external_upgrade_tasks for this role that has empty tripleo_delegate_to
# in test configuration and that leads to fail with error
# "Fail if tripleo_delegate_to is undefined" for undercloud node
sed -i '/ContrailControlOnly/,/ContrailDpdk/{//!d}' $role_file

echo $(date) "------------------ FINISHED: $0 ------------------"
