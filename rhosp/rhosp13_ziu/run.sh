#!/bin/bash -eu

#Check if it's running on undercloud node
hostname=$(hostname -s)
if [ "$hostname" != "undercloud" ]; then
   echo This script must be run on RHOSP13 undercloud node. Exiting
   exit 1
fi

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source $my_dir/functions.sh
cd
source rhosp-environment.sh
source ziu.sh || true
source stackrc

#Checking mandatory env variables
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTRAIL_CONTAINER_TAG

echo $(date) Preparing contrail images | tee -a run.log
#Download new contrail images and put them into local registry
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" ./contrail_containers.yaml
openstack overcloud container image upload --config-file ./contrail_containers.yaml


#Changing contrail-parameters.yaml
cp contrail-parameters.yaml contrail-parameters.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" contrail-parameters.yaml

#Distribute local mirrors configuration to overcloud nodes
for ip in $(openstack server list -c Networks -f value | cut -d '=' -f2); do
    scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
    ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
done


######################################################
#                  ZIU                               #
######################################################

echo $(date) openstack overcloud update prepare | tee -a run.log
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
     --roles-file tripleo-heat-templates/roles_data_contrail_aio.yaml \
     -e environment-rhel-registration.yaml \
     -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml \
     -e docker_registry.yaml

echo $(date) pre-syncing images to overcloud nodes. Stoping containers | tee -a run.log
~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh

#Upgrading contrail controllers
for node in $(openstack server list --name overcloud-contrailcontroller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done

#Upgrading openstack controllers
for node in $(openstack server list --name overcloud-controller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done

#Upgrading computes
for node in $(openstack server list --name overcloud-novacompute -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done

echo $(date) openstack overcloud update converge | tee -a run.log
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
     --roles-file tripleo-heat-templates/roles_data_contrail_aio.yaml \
     -e environment-rhel-registration.yaml \
     -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml \
     -e docker_registry.yaml



#Check /etc/rhsm/rhsm.conf
#manage_repos = 0
#report_package_profile = 0



