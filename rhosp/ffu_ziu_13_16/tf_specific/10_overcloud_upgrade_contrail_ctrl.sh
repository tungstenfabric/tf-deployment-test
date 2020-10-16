#!/bin/bash -eux


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

for node in $(openstack server list --name overcloud-contrailcontroller -c Name -f value) ; do
  openstack overcloud upgrade run --stack overcloud --tags system_upgrade --limit $node
  openstack overcloud upgrade run --stack overcloud --limit $node
done

echo $(date) "------------------ FINISHED: $0 ------------------"
