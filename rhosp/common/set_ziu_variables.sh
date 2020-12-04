#!/bin/bash

source /tmp/test.env
source rhosp-environment.sh

overcloud_prov_ip_list=''
overcloud_instance_list=''
for nodes in "$CONTROLLER_NODES" "$OPENSTACK_CONTROLLER_NODES" "$AGENT_NODES"; do
    for node in $(echo $nodes | sed "s/,/ /g"); do
        cutted_node="$(echo $node | cut -d "." -f1)"
        if [[ $overcloud_prov_ip_list != *"$node"* ]]; then
            overcloud_prov_ip_list+="$node "
        fi
        if [[ $overcloud_instance_list != *"$cutted_node"* ]]; then
            overcloud_instance_list+="$cutted_node "
        fi
    done
done

echo "$(date) overcloud_prov_ip_list:  $overcloud_prov_ip_list" | tee -a ~/ziu_run.log
echo "$(date) overcloud_instance_list: $overcloud_instance_list" | tee -a ~/ziu_run.log

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

echo "$(date) tls_env_files are $tls_env_files" | tee -a ~/ziu_run.log
rhel_reg_env_files=''
if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' ]] ; then
  rhel_reg_env_files+=" -e environment-rhel-registration.yaml"
  rhel_reg_env_files+=" -e tripleo-heat-templates/extraconfig/pre_deploy/rhel-registration/rhel-registration-resource-registry.yaml"
fi

echo "$(date) rhel_reg_env_files are $rhel_reg_env_files" | tee -a ~/ziu_run.log
network_env_files=''
if [[ ${ENABLE_NETWORK_ISOLATION+x} && "$ENABLE_NETWORK_ISOLATION" == true ]] ; then
    network_env_files+=' -e tripleo-heat-templates/environments/network-isolation.yaml'
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net.yaml'
else
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml'
fi

echo "$(date) network_env_files are $network_env_files" | tee -a ~/ziu_run.log
storage_env_files=''
if [[ ${overcloud_ceph_instance+x} && -n "$overcloud_ceph_instance" ]] ; then
    storage_env_files+=' -e tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml'
    storage_env_files+=' -e tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml'
fi
echo "$(date) storage_env_files are $storage_env_files" | tee -a ~/ziu_run.log

if [[ -z "$CONTROLLER_NODES" && -z "$AGENT_NODES" ]] ; then
  role_file="$(pwd)/tripleo-heat-templates/roles/ContrailAio.yaml"
else
  role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"
fi

echo "$(date) check for predeployed nodes [role_file is $role_file]" | tee -a ~/ziu_run.log
pre_deploy_nodes_env_files=''
if [[ ${USE_PREDEPLOYED_NODES+x} && "$USE_PREDEPLOYED_NODES" == true ]]; then
  pre_deploy_nodes_env_files+=" --disable-validations"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-environment.yaml"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-bootstrap-environment-rhel.yaml"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-pacemaker-environment.yaml"
  pre_deploy_nodes_env_files+=" -e ctlplane-assignments.yaml"
  pre_deploy_nodes_env_files+=" -e hostname-map.yaml"

  if [[ -z "$CONTROLLER_NODES" && -z "$AGENT_NODES" ]] ; then
    export OVERCLOUD_ROLES="ContrailAio"
    export ContrailAio_hosts="${overcloud_cont_prov_ip//,/ }"
  else
    export OVERCLOUD_ROLES="Controller Compute ContrailController"
    export Controller_hosts="${overcloud_cont_prov_ip//,/ }"
    export Compute_hosts="${overcloud_compute_prov_ip//,/ }"
    export ContrailController_hosts="${overcloud_ctrlcont_prov_ip//,/ }"
  fi
fi

