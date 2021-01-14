#!/bin/bash

source /tmp/test.env
source rhosp-environment.sh

tls_env_files=''
if [[ "$ENABLE_TLS" == 'ipa' ]] ; then
  tls_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-tls.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/ssl/tls-everywhere-endpoints-dns.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/services/haproxy-public-tls-certmonger.yaml'
  tls_env_files+=' -e tripleo-heat-templates/environments/ssl/enable-internal-tls.yaml'
else
  # use names even w/o tls case
  tls_env_files+=' -e tripleo-heat-templates/environments/contrail/endpoints-public-dns.yaml'
fi

#Now --yes is needed only on fresh red hat repos. Later this option would be needed for bmc and vexx
yes=''
rhel_reg_env_files=''
if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' && "$USE_PREDEPLOYED_NODES" != 'true' ]] ; then
  # use rhel registration options in enabled and for non predeployed nodes.
  # for predeployed nodes registration is made in rhel_provisioning.sh
  yes=' --yes'
  rhel_reg_env_files+=" -e tripleo-heat-templates/environments/rhsm.yaml"
  rhel_reg_env_files+=" -e rhsm.yaml"
fi

network_env_files=''
if [[ "$ENABLE_NETWORK_ISOLATION" == true ]] ; then
    network_env_files+=' -e tripleo-heat-templates/environments/network-isolation.yaml'
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net.yaml'
else
    network_env_files+=' -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml'
fi

if [[ -z "$CONTROLLER_NODES" && -z "$AGENT_NODES" ]] ; then
  role_file="$(pwd)/tripleo-heat-templates/roles/ContrailAio.yaml"
else
  role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"
fi


pre_deploy_nodes_env_files=''
if [[ ${USE_PREDEPLOYED_NODES+x} && "$USE_PREDEPLOYED_NODES" == true ]]; then
  pre_deploy_nodes_env_files+=" --disable-validations"
  pre_deploy_nodes_env_files+=" --deployed-server"
  pre_deploy_nodes_env_files+=" --overcloud-ssh-user $SSH_USER"
  pre_deploy_nodes_env_files+=" --overcloud-ssh-key .ssh/id_rsa"
  pre_deploy_nodes_env_files+=" -e tripleo-heat-templates/environments/deployed-server-environment.yaml"
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
