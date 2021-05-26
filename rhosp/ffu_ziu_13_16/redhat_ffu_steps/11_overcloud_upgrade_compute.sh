#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

#19.3. Upgrading Compute nodes
for node in $(openstack server list --name overcloud-novacompute -c Name -f value) ; do
  source $my_dir/../tf_specific/11_overcloud_upgrade_compute.sh
  openstack overcloud upgrade run $force --stack overcloud --limit $node
done

echo $(date) "------------------ FINISHED: $0 ------------------"
