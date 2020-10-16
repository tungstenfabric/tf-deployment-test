#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

role_file="$(pwd)/tripleo-heat-templates/roles_data_contrail_aio.yaml"

sed -i '/ceph3_.*\|.*_stein/d' containers-prepare-parameter.yaml

#17.5. Synchronizing the overcloud stack

openstack overcloud upgrade converge \
  --templates tripleo-heat-templates/ \
  --stack overcloud --libvirt-type kvm \
  --roles-file $role_file \
  -e tripleo-heat-templates/environments/rhsm.yaml \
  -e rhsm.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-net-single.yaml \
  -e tripleo-heat-templates/environments/contrail/endpoints-public-dns.yaml \
  -e tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
  -e misc_opts.yaml \
  -e contrail-parameters.yaml \
  -e containers-prepare-parameter.yaml \
  -e tripleo-heat-templates/upgrades-environment.yaml \
  -e tripleo-heat-templates/workaround.yaml

echo $(date) "------------------ FINISHED: $0 ------------------"
