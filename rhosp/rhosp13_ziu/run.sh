#!/bin/bash -eu
echo "1" >> this_bash_works
#Check if it's running on undercloud node
hostname=$(hostname -s)
if [ "$hostname" != "undercloud" ]; then
   echo This script must be run on RHOSP13 undercloud node. Exiting
   exit 1
fi
echo "2" >> this_bash_works
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source $my_dir/../common/functions.sh
cd
source rhosp-environment.sh
source ziu.sh || true
source stackrc
echo "3" >> this_bash_works
#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTAINER_REGISTRY
echo "4" >> this_bash_works
echo $(date) Preparing contrail images | tee -a run.log
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY} -t ${CONTRAIL_NEW_IMAGE_TAG}
cat contrail_containers.yaml
echo "5" >> this_bash_works
#Download new contrail images and put them into local registry
openstack overcloud container image upload --config-file ./contrail_containers.yaml
echo "6" >> this_bash_works
#Changing misc_opts.yaml
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml
echo misc_opts.yaml was changed
cat misc_opts.yaml
echo "7" >> this_bash_works
#Distribute local mirrors configuration to overcloud nodes
for ip in $(openstack server list -c Networks -f value | cut -d '=' -f2); do
    scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
    ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
done
echo "8" >> this_bash_works
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
echo "9" >> this_bash_works
#Upgrading contrail controllers
for node in $(openstack server list --name overcloud-contrailcontroller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done
echo "10" >> this_bash_works
#Upgrading openstack controllers
for node in $(openstack server list --name overcloud-controller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done
echo "11" >> this_bash_works
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

echo $(date) Successfully finished | tee -a run.log
echo "12" >> this_bash_works
