#!/bin/bash -e

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
source $my_dir/collect_contrail_version.sh
cd
source rhosp-environment.sh
source stackrc
source /tmp/test.env

printenv > ziu_env
echo "$(date) INFO:  env in ziu_env"
#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTAINER_REGISTRY_ORIGINAL
checkForVariable CONTRAIL_CONTAINER_TAG
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable USE_PREDEPLOYED_NODES
checkForVariable ENABLE_RHEL_REGISTRATION

echo "$(date) INFO:  preparing contrail images"
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY_ORIGINAL} -t ${CONTRAIL_NEW_IMAGE_TAG}

echo "$(date) INFO:  prov_ip for contrail_containers.yaml: $prov_ip"
sed -i ./contrail_containers.yaml -e "s/192.168.24.1/${prov_ip}/"

cat contrail_containers.yaml

#Download new contrail images and put them into local registry
echo "$(date) INFO:  download new contrail images and put them into local registry"
openstack overcloud container image upload --config-file ./contrail_containers.yaml

#Changing misc_opts.yaml
echo "$(date) INFO:  change misc_opts.yaml"
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml
echo "$(date) misc_opts.yaml was changed"
cat misc_opts.yaml

if [[ "$ENABLE_RHEL_REGISTRATION" == 'false' && "$USE_PREDEPLOYED_NODES" == 'false' ]]; then
    echo "$(date) INFO:  Distribute local mirrors configuration to overcloud nodes"
    #Distribute local mirrors configuration to overcloud nodes
    for ip in $overcloud_prov_ip_list; do
        scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
        ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
    done
fi

collect_contrail_version $SSH_USER ${log_path}/contrail_version.before_ziu $overcloud_prov_ip_list

######################################################
#                  ZIU                               #
######################################################
echo "$(date)  INFO:   openstack overcloud update prepare"
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user tripleo-admin \
     --roles-file $role_file \
     -e docker_registry.yaml \
     $rhel_reg_env_files \
     $pre_deploy_nodes_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     $network_env_files \
     $storage_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     $tls_env_files \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml

#This step doens't work properly in openstack environment becouse it can't get ip addresses of the nodes in openstack undercloud.
#TODO create the procedure which is working for openstack
#echo "$(date) INFO:  pre-syncing images to overcloud nodes. stop containers"
#~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh

update_contrail_preparation $overcloud_prov_ip_list

for node in $overcloud_instance_list; do
    echo "$(date) INFO:  Upgrading $node"
    openstack overcloud update run --ssh-user tripleo-admin --nodes $node
done

echo "$(date) INFO:  openstack overcloud update converge"
openstack overcloud update converge --templates tripleo-heat-templates/ \
     --overcloud-ssh-user tripleo-admin \
     --roles-file $role_file \
     -e docker_registry.yaml \
     $rhel_reg_env_files \
     $pre_deploy_nodes_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     $network_env_files \
     $storage_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     $tls_env_files \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml

echo "$(date) INFO: Sync time on the overcloud nodes"
sync_time $SSH_USER $overcloud_prov_ip_list

collect_contrail_version $SSH_USER ${log_path}/contrail_version.after_ziu $overcloud_prov_ip_list


echo "$(date) Successfully finished"

