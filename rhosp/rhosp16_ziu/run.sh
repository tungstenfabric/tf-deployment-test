#!/bin/bash -eu

echo "" | tee -a ziu_run.log
echo "$(date) start run.sh" | tee -a ziu_run.log
#Check if it's running on undercloud node
hostname=$(hostname -s)
if [[ ${hostname} != *"undercloud"* ]]; then
   echo This script must be run on RHOSP13 undercloud node. Exiting
   exit 1
fi

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"
set -a
source $my_dir/../common/functions.sh
source $my_dir/../common/set_common_ziu_var.sh
source $my_dir/set_ziu_variables.sh
source /tmp/test.env

cd
source rhosp-environment.sh
source stackrc
printenv > ziu_env
echo "$(date) env in ziu_env" | tee -a ziu_run.log
#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTAINER_REGISTRY_ORIGINAL
checkForVariable CONTRAIL_CONTAINER_TAG
checkForVariable USE_PREDEPLOYED_NODES
checkForVariable ENABLE_RHEL_REGISTRATION


########################### UPLOAD #####################################

echo "$(date) preparing contrail images" | tee -a ziu_run.log
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY_ORIGINAL} -t ${CONTRAIL_NEW_IMAGE_TAG}
sed -i ./contrail_containers.yaml -e "s/192.168.24.1/${prov_ip}/"

cat contrail_containers.yaml
echo "$(date) download new contrail images and put them into local registry" | tee -a ziu_run.log
sudo openstack overcloud container image upload --config-file ./contrail_containers.yaml

echo "$(date) change misc_opts.yaml" | tee -a ziu_run.log
#Changing misc_opts.yaml
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml

if [[ "$USE_PREDEPLOYED_NODES" == 'true' ]]; then
   echo "  SkipRhelEnforcement: true" >> misc_opts.yaml
fi

echo misc_opts.yaml was changed
cat misc_opts.yaml

if [[ "$ENABLE_RHEL_REGISTRATION" == 'false' && "$USE_PREDEPLOYED_NODES" == 'false' ]]; then
    echo "$(date) Distribute local mirrors configuration to overcloud nodes" | tee -a ziu_run.log
    #Distribute local mirrors configuration to overcloud nodes
    for ip in $overcloud_prov_ip_list; do
        scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
        ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
    done
fi


######################################################
#                  ZIU                               #
######################################################

./tripleo-heat-templates/tools/process-templates.py --clean \
  -r $role_file \
  -p tripleo-heat-templates/

./tripleo-heat-templates/tools/process-templates.py \
  -r $role_file \
  -p tripleo-heat-templates/


openstack overcloud update prepare --templates tripleo-heat-templates/ \
  --stack overcloud --libvirt-type kvm \
  --roles-file $role_file \
  -e overcloud_containers.yaml \
  $rhel_reg_env_files \
  $pre_deploy_nodes_env_files \
  -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  $network_env_files \
  -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
  $tls_env_files \
  -e misc_opts.yaml \
  -e contrail-parameters.yaml \
  -e containers-prepare-parameter.yaml

echo "$(date) pre-syncing images to overcloud nodes. stop containers" | tee -a ziu_run.log
~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh

echo "$(date) upgrading nodes" | tee -a ziu_run.log
echo "$(date)  $overcloud_instance_list" | tee -a ziu_run.log

for node in $overcloud_instance_list; do
    echo "$(date) Upgrading $node" | tee -a ziu_run.log
    openstack overcloud update run --ssh-user tripleo-admin --limit $node
done

echo "$(date) openstack overcloud update converge" | tee -a ziu_run.log
openstack overcloud update converge --templates tripleo-heat-templates/ \
  --stack overcloud --libvirt-type kvm \
  --roles-file $role_file \
  -e overcloud_containers.yaml \
  $rhel_reg_env_files \
  $pre_deploy_nodes_env_files \
  -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  $network_env_files \
  -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
  $tls_env_files \
  -e misc_opts.yaml \
  -e contrail-parameters.yaml \
  -e containers-prepare-parameter.yaml


echo "$(date) Successfully finished" | tee -a ziu_run.log
