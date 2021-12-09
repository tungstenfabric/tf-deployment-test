#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"


cd ~
source stackrc
source rhosp-environment.sh

upgrade_plan=${1:-'overcloud_controlplane_upgrade_plan'}

#Detecting pacemaker bootstrap node
ctrl_ip=$(openstack server list --name overcloud-controller-0 -c Networks -f value | cut -d '=' -f2)
[[ -n "$ctrl_ip" ]]

node_admin_username=${NODE_ADMIN_USERNAME:-'heat-admin'}
pcs_bootstrap_node=$(ssh $node_admin_username@$ctrl_ip "sudo hiera -c /etc/puppet/hiera.yaml pacemaker_short_bootstrap_node_name")
[[ -n "$pcs_bootstrap_node" ]]

echo "pcs_bootstrap_node detected: $pcs_bootstrap_node"


if [ -f $upgrade_plan ]; then
   echo "File $upgrade_plan already exists. Remove it first. Exiting"
   exit 1
fi


rm -f /tmp/overcloud_controlplane_upgrade_plan || true
#Getting batches for parallel upgrade
for ((i=0;i<3;i++)) ; do
  node=''
  batch=''
  for node in $(openstack server list -c Name -f value | grep controller | grep ${i}); do
      if [[ -n "$EXTERNAL_CONTROLLER_NODES" && $node =~ 'contrailcontroller' ]]; then
          echo "INFO: Excluding $node from upgrade_plan because EXTERNAL_CONTROLLER_NODES is using (CN21.2 upgrade mode)"
      else 
          if [ -z $batch ]; then
              batch+="$node"
          else
              batch+=",$node"
          fi
      fi
  done
  if echo "$batch" | grep -q $pcs_bootstrap_node; then
      echo "000-bootstrap-label:$batch" >> /tmp/overcloud_controlplane_upgrade_plan
  else
      echo "$batch" >> /tmp/overcloud_controlplane_upgrade_plan
  fi
done

#Sort overcloud_controlplane_upgrade_plan to get bootstrap node at the first line
cat /tmp/overcloud_controlplane_upgrade_plan | sort > $upgrade_plan
#Removing 000-bootstrap-label
sed -i s/000-bootstrap-label:// $upgrade_plan

echo "Overcloud upgrade plan for control plane created (can be edited before running update)"
echo $upgrade_plan
cat $upgrade_plan

echo $(date) "------------------ FINISHED: $0 ------------------"

