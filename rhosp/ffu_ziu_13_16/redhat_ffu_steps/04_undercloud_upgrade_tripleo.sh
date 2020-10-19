#!/bin/bash -eux

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

exec 3>&1 1> >(tee ${0}.log) 2>&1
echo $(date) "------------------ STARTED: $0 -------------------"

cd ~
source stackrc
source rhosp-environment.sh

#6.3. INSTALLING DIRECTOR PACKAGES
sudo dnf install -y python3-tripleoclient


echo Generating yaml files
[[ -n "$RHEL_POOL_ID" && -n "$RHEL_USER" && -n "$RHEL_PASSWORD" ]]

#10.1. Red Hat Subscription Manager (RHSM) composable service
cat $my_dir/../redhat_files/rhsm.yaml.template | envsubst > rhsm.yaml

#6.5. CONTAINER IMAGE PREPARATION PARAMETERS
cat $my_dir/..//redhat_files/containers-prepare-parameter.yaml.template | envsubst > containers-prepare-parameter.yaml

#6.8. UPDATING THE UNDERCLOUD.CONF FILE
sed -i '/undercloud_public_host\|undercloud_admin_host\|container_images_file/d' undercloud.conf
sed -i "/\[DEFAULT\]/ a undercloud_public_host = ${undercloud_public_host}" undercloud.conf
sed -i "/\[DEFAULT\]/ a undercloud_admin_host = ${undercloud_admin_host}" undercloud.conf
sed -i "/\[DEFAULT\]/ a container_images_file = containers-prepare-parameter.yaml" undercloud.conf
sed -i "s/eth/em/" undercloud.conf
cat undercloud.conf

#6.10. RUNNING THE DIRECTOR UPGRADE
openstack undercloud upgrade -y

echo undercloud tripleo upgrade finished. Checking status
sudo systemctl list-units --no-pager "tripleo_*"
sudo podman ps --all
echo $(date) "------------------ FINISHED: $0 ------------------"
