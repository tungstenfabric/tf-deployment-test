#!/bin/bash
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source $my_dir/functions.sh

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"/root/.tf"}

export CONTAINER_REGISTRY="$CONTAINER_REGISTRY_ORIGINAL"
export CONTRAIL_CONTAINER_TAG="$CONTRAIL_CONTAINER_TAG_ORIGINAL$TAG_SUFFIX"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}

# working environment
tf_deployer_dir=${TF_ANSIBLE_DEPLOYER_DIR:-"${HOME}/tf-ansible-deployer"}
openstack_deployer_dir=${HOME}/contrail-kolla-ansible
tf_deployer_image=${TF_ANSIBLE_DEPLOYER:-"tf-ansible-deployer-src"}
openstack_deployer_image=${OPENSTACK_DEPLOYER:-"tf-kolla-ansible-src"}

fetch_deployer $tf_deployer_image $tf_deployer_dir
fetch_deployer $openstack_deployer_image $openstack_deployer_dir

cd $tf_deployer_dir

# Upgrade contrail_container_tag in new_instances.yaml
python3 $my_dir/change_container_tag.py < $TF_CONFIG_DIR/instances.yaml > $TF_CONFIG_DIR/ziu_instances.yaml

# Run controller stage of ziu.yml
sudo -E ansible-playbook -v -e stage=controller -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

# Run openstack stage of ziu.yml
sudo -E ansible-playbook -v -e stage=openstack -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

# TODO(tikitavi): is it neccessary
wait_cmd_success 10 60 "check_tf_active"

#Run compute stage of ziu.yml
sudo -E ansible-playbook -v -e stage=compute -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

wait_cmd_success 10 60 "check_tf_active"

if [[ ! check_tf_active ]] ; then
    echo "ERROR: tf is not active after ziu"
    exit 1
fi

if [[ ! check_tag $CONTRAIL_CONTAINER_TAG ]] ; then
    echo "ERROR: containers has the wrong tag"
    exit 1
fi
