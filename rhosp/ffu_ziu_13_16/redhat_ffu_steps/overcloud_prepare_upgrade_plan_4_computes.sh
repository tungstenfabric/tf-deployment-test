#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"


cd ~
source stackrc
source rhosp-environment.sh

upgrade_plan=${1:-'overcloud_compute_upgrade_plan'}

if [ -f $upgrade_plan ]; then
   echo "File $upgrade_plan already exists. Remove it first. Exiting"
   exit 1
fi

rm -f /tmp/overcloud_compute_upgrade_plan || true
#Getting batches for parallel upgrade
for ((i=0;i<3;i++)) ; do
  node=''
  batch=''
  for node in $(openstack server list -c Name -f value | grep -E 'compute|dpdk|sriov' | grep ${i}); do
      if [ -z $batch ]; then
          batch+="$node"
      else
          batch+=",$node"
      fi
  done
  echo "$batch" >> /tmp/overcloud_compute_upgrade_plan
done

cat /tmp/overcloud_compute_upgrade_plan | grep -v '^$' | sort > $upgrade_plan

echo "Overcloud upgrade plan for control plane created (can be edited before running update)"
echo $upgrade_plan
cat $upgrade_plan

echo $(date) "------------------ FINISHED: $0 ------------------"

