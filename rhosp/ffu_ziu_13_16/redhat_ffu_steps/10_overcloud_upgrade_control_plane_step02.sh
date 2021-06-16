#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"


exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

upgrade_plan=${1:-'overcloud_controlplane_upgrade_plan'}

if [[ ! -f $upgrade_plan ]]; then
    echo "File $upgrade_plan not found. Please prepare overcloud_controlplane_upgrade_plan. Exit"
    exit 1
fi


i=1
limit=''
while IFS= read -r line; do
    if [ -z $limit ]; then
        limit+="$line"
    else
        limit+=",$line"
    fi
    #Skipping first line of upgrade_plane
    if [[ $i>1 ]]; then
        $my_dir/run_overcloud_system_upgrade.sh $line
        $my_dir/run_overcloud_openstack_upgrade.sh $limit
    fi
    ((i++))
done <"$upgrade_plan"

echo $(date) "------------------ FINISHED: $0 ------------------"
