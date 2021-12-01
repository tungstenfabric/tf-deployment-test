#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"

./tripleo-heat-templates/tools/process-templates.py --clean \
  -r $role_file \
  -p tripleo-heat-templates/

./tripleo-heat-templates/tools/process-templates.py \
  -r $role_file \
  -p tripleo-heat-templates/

#Network template
network_parameters="-e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml"

#Local mirrors case (CICD)
rhsm_parameters=''
if [[ "${ENABLE_RHEL_REGISTRATION,,}" == 'true' ]] ; then
  #Red Hat Registration case
  rhsm_parameters+=' -e rhsm.yaml'
  rhsm_parameters+=' -e tripleo-heat-templates/environments/rhsm.yaml'
fi

overcloud_ssh_user=''
if [[ -n "$NODE_ADMIN_USERNAME" && "$NODE_ADMIN_USERNAME" != "heat-admin" ]] ; then
    overcloud_ssh_user="--overcloud-ssh-user $NODE_ADMIN_USERNAME"
fi

if [[ "$ENABLE_TLS" != 'ipa' ]] ; then
  tls_opts='-e tripleo-heat-templates/environments/contrail/endpoints-public-dns.yaml'
else
  tls_opts='-e tripleo-heat-templates/environments/contrail/contrail-tls.yaml'
  tls_opts+=' -e tripleo-heat-templates/environments/ssl/tls-everywhere-endpoints-dns.yaml'
  tls_opts+=' -e tripleo-heat-templates/environments/services/haproxy-public-tls-certmonger.yaml'
  tls_opts+=' -e tripleo-heat-templates/environments/ssl/enable-internal-tls.yaml'
fi

#19.1. Running the overcloud upgrade preparation
openstack overcloud upgrade prepare --yes \
  --templates tripleo-heat-templates/ \
  --stack overcloud --libvirt-type kvm \
  --roles-file $role_file \
  $overcloud_ssh_user \
  $rhsm_parameters \
  $network_parameters \
  $tls_opts \
  -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
  -e misc_opts.yaml \
  -e contrail-parameters.yaml \
  -e containers-prepare-parameter.yaml \
  -e tripleo-heat-templates/upgrades-environment.yaml \
  $FFU_EXTRA_HEAT_ENVIRONMENTS

openstack overcloud external-upgrade run --yes --stack overcloud --tags container_image_prepare

echo $(date) "------------------ FINISHED: $0 ------------------"
