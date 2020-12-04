#!/bin/bash -eu

#Check if it's running on undercloud node
hostname=$(hostname -s)
if [[ ${hostname} != *"undercloud"* ]]; then
   echo This script must be run on RHOSP13 undercloud node. Exiting
   exit 1
fi

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source $my_dir/../common/functions.sh
cd
source rhosp-environment.sh
source ziu.sh || true
source stackrc
printenv > ziu_env
#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTAINER_REGISTRY

if [[ "$USE_PREDEPLOYED_NODES" == true ]]; then
  pre_deploy_nodes_env_files+=" --disable-validations"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-environment.yaml"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-bootstrap-environment-rhel.yaml"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-pacemaker-environment.yaml"
  pre_deploy_nodes_env_files+=" -e ctlplane-assignments.yaml"
  pre_deploy_nodes_env_files+=" -e hostname-map.yaml"

  if [[ -z "$overcloud_ctrlcont_instance" && -z "$overcloud_compute_instance" ]] ; then
    export OVERCLOUD_ROLES="ContrailAio"
    export ContrailAio_hosts="${overcloud_cont_prov_ip//,/ }"
  else
    export OVERCLOUD_ROLES="Controller Compute ContrailController"
    export Controller_hosts="${overcloud_cont_prov_ip//,/ }"
    export Compute_hosts="${overcloud_compute_prov_ip//,/ }"
    export ContrailController_hosts="${overcloud_ctrlcont_prov_ip//,/ }"
  fi
  nohup tripleo-heat-templates/deployed-server/scripts/get-occ-config.sh &
  job=$!
fi


echo $(date) Preparing contrail images | tee -a run.log
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY} -t ${CONTRAIL_NEW_IMAGE_TAG}
echo "prov_ip: $prov_ip" | tee -a run.log
sed -i ./contrail_containers.yaml -e "s/192.168.24.1/${prov_ip}/"

cat contrail_containers.yaml
echo $(date) contrail-tripleo-heat-templates | tee -a run.log
#Download new contrail images and put them into local registry
openstack overcloud container image upload --config-file ./contrail_containers.yaml
echo $(date) Download new contrail images and put them into local registry | tee -a run.log
#Changing misc_opts.yaml
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml
echo misc_opts.yaml was changed
cat misc_opts.yaml
echo $(date) Distribute local mirrors configuration to overcloud node | tee -a run.log
#Distribute local mirrors configuration to overcloud nodes
for ip in $(openstack server list -c Networks -f value | cut -d '=' -f2); do
    scp /etc/yum.repos.d/local.repo $SSH_USER@$ip:
    ssh $SSH_USER@$ip "sudo cp local.repo /etc/yum.repos.d/"
done

######################################################
#                  ZIU                               #
######################################################
if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' ]] ; then
    rhel_registration="-e environment-rhel-registration.yaml -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml"
else
    rhel_registration=""
fi
echo $(date) openstack overcloud update prepare | tee -a run.log
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
     --roles-file tripleo-heat-templates/roles_data_contrail_aio.yaml \
     $rhel_registration \
     $pre_deploy_nodes_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml \
     -e docker_registry.yaml

echo $(date) pre-syncing images to overcloud nodes. Stoping containers | tee -a run.log
~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh
echo $(date) update_contrail_preparation | tee -a run.log
#Upgrading contrail controllers
for node in $(openstack server list --name overcloud-contrailcontroller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done
echo $(date) Upgrading contrail controllers | tee -a run.log
#Upgrading openstack controllers
for node in $(openstack server list --name overcloud-controller -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done
echo $(date) Upgrading openstack controllers | tee -a run.lo
#Upgrading computes
for node in $(openstack server list --name overcloud-novacompute -c Name -f value); do
    echo $(date) Upgrading $node | tee -a run.log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done

echo $(date) openstack overcloud update converge | tee -a run.log
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
     --roles-file tripleo-heat-templates/roles_data_contrail_aio.yaml \
     $rhel_registration \
     $pre_deploy_nodes_env_files \
     -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml \
     -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
     -e misc_opts.yaml \
     -e contrail-parameters.yaml \
     -e docker_registry.yaml

echo $(date) Successfully finished | tee -a run.log
echo "Successfully finished!" > it_works

