#!/bin/bash -eu

#Check if it's running on undercloud node
hostname=$(hostname -s)
if [[ ${hostname} != *"undercloud"* ]]; then
   echo This script must be run on RHOSP16 undercloud node. Exiting
   exit 1
fi

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"
set -a
source $my_dir/../common/functions.sh
source $my_dir/../common/set_common_ziu_var.sh
source $my_dir/set_ziu_variables.sh
source $my_dir/collect_contrail_version.sh
source /tmp/test.env

cd
source rhosp-environment.sh
source stackrc
echo "$(date) INFO:  env in ziu_env"
printenv > ziu_env
#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTAINER_REGISTRY_ORIGINAL
checkForVariable CONTRAIL_CONTAINER_TAG
checkForVariable USE_PREDEPLOYED_NODES
checkForVariable ENABLE_RHEL_REGISTRATION


########################### UPLOAD #####################################
echo "$(date) INFO:  preparing contrail images"
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY_ORIGINAL} -t ${CONTRAIL_NEW_IMAGE_TAG}
sed -i ./contrail_containers.yaml -e "s/192.168.24.1/${prov_ip}/"

cat contrail_containers.yaml
echo "$(date) INFO:  download new contrail images and put them into local registry"
sudo openstack overcloud container image upload --config-file ./contrail_containers.yaml

#Changing misc_opts.yaml
echo "$(date) INFO:  change misc_opts.yaml"
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml

if [[ "$USE_PREDEPLOYED_NODES" == 'true' ]]; then
   echo "  SkipRhelEnforcement: true" >> misc_opts.yaml
fi

echo misc_opts.yaml was changed
cat misc_opts.yaml

if [[ "$ENABLE_RHEL_REGISTRATION" == 'false' && "$USE_PREDEPLOYED_NODES" == 'false' ]]; then
    echo "$(date) INFO:  Distribute local mirrors configuration to overcloud nodes"
    #Distribute local mirrors configuration to overcloud nodes
    for ip in $overcloud_prov_ip_list; do
        scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
        ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
    done
fi

if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' && "$USE_PREDEPLOYED_NODES" == 'false' ]]; then
    echo "$(date) INFO:  sudo subscription-manager release --set=8.2 on overcloud nodes"
    for ip in $overcloud_prov_ip_list; do
        ssh $SSH_USER@$ip "sudo subscription-manager release --set=8.2"
    done
fi



collect_contrail_version $SSH_USER ${log_path}/contrail_version.before_ziu $overcloud_prov_ip_list

######################################################
#                  ZIU                               #
######################################################
echo "$(date) INFO:  prepare templates"
./tripleo-heat-templates/tools/process-templates.py --clean \
  -r $role_file \
  -p tripleo-heat-templates/

./tripleo-heat-templates/tools/process-templates.py \
  -r $role_file \
  -p tripleo-heat-templates/

echo "$(date) INFO:  openstack overcloud update prepare"
openstack overcloud update prepare --templates tripleo-heat-templates/ \
  $yes \
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

#This step doens't work properly in vexx environment becouse it can't get ip addresses of the nodes in openstack undercloud.
#we use functions update_contrail_preparation in VEXX
#echo "$(date) INFO:  update_contrail_preparation.sh"
#~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh

update_contrail_preparation $overcloud_prov_ip_list

for node in $overcloud_instance_list; do
    echo "$(date) INFO:  Upgrading $node"
    openstack overcloud update run $yes --ssh-user tripleo-admin --limit $node
done


echo "$(date) INFO:  openstack overcloud update converge"
openstack overcloud update converge --templates tripleo-heat-templates/ \
  $yes \
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

echo "$(date) INFO: Sync time on the overcloud nodes"
sync_time $SSH_USER $overcloud_prov_ip_list

collect_contrail_version $SSH_USER ${log_path}/contrail_version.after_ziu $overcloud_prov_ip_list

echo "$(date) Successfully finished"
