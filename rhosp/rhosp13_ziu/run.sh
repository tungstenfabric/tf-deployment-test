#!/bin/bash -eu
set -x

echo "" | tee -a ziu_run.log
echo "$(date) start ziu's run.sh" | tee -a ziu_run.log

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
echo "$(date) env in ziu_env" | tee -a ziu_run.log

#Checking mandatory env variables
checkForVariable SSH_USER
checkForVariable CONTRAIL_NEW_IMAGE_TAG
checkForVariable CONTAINER_REGISTRY


if [[ "$PROVIDER" == "vexx" ]]; then
    overcloud_prov_ip_list=$(echo "$overcloud_ctrlcont_prov_ip,$overcloud_cont_prov_ip,$overcloud_compute_prov_ip" | sed "s/,/ /g")
    overcloud_instance_list=$(echo "$overcloud_ctrlcont_instance,$overcloud_cont_instance,$overcloud_compute_instance" | sed "s/,/ /g")
else
    overcloud_prov_ip_list=$(openstack server list -c Networks -f value | cut -d '=' -f2)
    overcloud_instance_list=''
    for name in "overcloud-contrailcontroller" "overcloud-controller" "overcloud-novacompute"; do
        overcloud_instance_list+="$(openstack server list --name $name -c Name -f value) "
    done
fi

tls_env_files=''
if [[ -n "$ENABLE_TLS" ]] ; then
  tls_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-tls.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/ssl/tls-everywhere-endpoints-dns.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/services/haproxy-public-tls-certmonger.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/ssl/enable-internal-tls.yaml'
else
  # use names even w/o tls case
  tls_env_files+=' -e tripleo-heat-templates/environments/contrail/endpoints-public-dns.yaml'
fi

echo "$(date) tls_env_files are $tls_env_files" | tee -a ziu_run.log
rhel_reg_env_files=''
if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' ]] ; then
  rhel_reg_env_files+=" -e environment-rhel-registration.yaml"
  rhel_reg_env_files+=" -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml"
fi

echo "$(date) rhel_reg_env_files are $rhel_reg_env_files" | tee -a ziu_run.log
network_env_files=''
if [[ "$ENABLE_NETWORK_ISOLATION" == true ]] ; then
    network_env_files+=' -e tripleo-heat-templates/environments/network-isolation.yaml'
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net.yaml'
else
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml'
fi

echo "$(date) network_env_files are $network_env_files" | tee -a ziu_run.log
storage_env_files=''
if [[ ${overcloud_ceph_instance+x} && -n "$overcloud_ceph_instance" ]] ; then
    storage_env_files+=' -e tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml'
    storage_env_files+=' -e tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml'
fi
echo "$(date) storage_env_files are $storage_env_files" | tee -a ziu_run.log

if [[ -z "$overcloud_ctrlcont_instance" && -z "$overcloud_compute_instance" ]] ; then
  role_file="$(pwd)/tripleo-heat-templates/roles/ContrailAio.yaml"
else
  role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"
fi

echo "$(date) check for predeployed nodes [role_file is $role_file]" | tee -a ziu_run.log
pre_deploy_nodes_env_files=''
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
fi


echo "$(date) preparing contrail images" | tee -a ziu_run.log
mv contrail_containers.yaml contrail_containers.yaml.before_ziu
./contrail-tripleo-heat-templates/tools/contrail/import_contrail_container.sh \
    -f ./contrail_containers.yaml -r ${CONTAINER_REGISTRY} -t ${CONTRAIL_NEW_IMAGE_TAG}

echo "prov_ip: $prov_ip" | tee -a ziu_run.log
sed -i ./contrail_containers.yaml -e "s/192.168.24.1/${prov_ip}/"

cat contrail_containers.yaml

echo "$(date) download new contrail images and put them into local registry" | tee -a ziu_run.log
#Download new contrail images and put them into local registry
openstack overcloud container image upload --config-file ./contrail_containers.yaml

echo "$(date) change misc_opts.yaml" | tee -a ziu_run.log
#Changing misc_opts.yaml
cp misc_opts.yaml misc_opts.yaml.before_ziu
sed -i "s/${CONTRAIL_CONTAINER_TAG}/${CONTRAIL_NEW_IMAGE_TAG}/" misc_opts.yaml
echo misc_opts.yaml was changed
cat misc_opts.yaml

echo "$(date) Distribute local mirrors configuration to overcloud node" | tee -a ziu_run.log
#Distribute local mirrors configuration to overcloud nodes
ssh_user=$(whoami)
for ip in $overcloud_prov_ip_list; do
    scp /etc/yum.repos.d/local.repo $ssh_user@$ip:
    ssh $ssh_user@$ip "sudo cp local.repo /etc/yum.repos.d/"
done

######################################################
#                  ZIU                               #
######################################################
openstack overcloud update prepare --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
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

echo "$(date) pre-syncing images to overcloud nodes. stop containers" | tee -a ziu_run.log
~/contrail-tripleo-heat-templates/tools/contrail/update_contrail_preparation.sh

echo "$(date) upgrading nodes" | tee -a ziu_run.log

echo "$(date)  $overcloud_instance_list" | tee -a ziu_run.log
for node in $overcloud_instance_list; do
    echo "$(date) Upgrading $node" >> z_ziu_log
    openstack overcloud update run --ssh-user $SSH_USER --nodes $node
done

echo "$(date) openstack overcloud update converge" | tee -a ziu_run.log
openstack overcloud update converge --templates tripleo-heat-templates/ \
     --overcloud-ssh-user $SSH_USER \
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

echo "$(date) Successfully finished" >> | tee -a ziu_run.log
echo "$(date)  Successfully finished!" > it_works

