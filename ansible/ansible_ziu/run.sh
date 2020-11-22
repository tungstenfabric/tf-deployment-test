#!/bin/bash
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

# working environment
TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
TF_ANSIBLE_DEPLOYER_DIR=${TF_ANSIBLE_DEPLOYER_DIR:-"${HOME}/tf-ansible-deployer"}

source $my_dir/../../common/functions.sh

cd $TF_ANSIBLE_DEPLOYER_DIR

tf_deployer_dir=${HOME}/tf-ansible-deployer
openstack_deployer_dir=${HOME}/contrail-kolla-ansible
tf_deployer_image=${TF_ANSIBLE_DEPLOYER:-"tf-ansible-deployer-src"}
openstack_deployer_image=${OPENSTACK_DEPLOYER:-"tf-kolla-ansible-src"}

fetch_deployer_no_docker $tf_deployer_image $tf_deployer_dir
fetch_deployer_no_docker $openstack_deployer_image $openstack_deployer_dir

# Upgrade contrail_container_tag in new_instances.yaml
python3 $my_dir/change_container_tag.py < $TF_CONFIG_DIR/instances.yaml > $TF_CONFIG_DIR/ziu_instances.yaml

# Run controller stage of ziu.yml
sudo -E ansible-playbook -v -e stage=controller -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

# Run openstack stage of ziu.yml
sudo -E ansible-playbook -v -e stage=openstack -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

#Run compute stage of ziu.yml
sudo -E ansible-playbook -v -e stage=compute -e orchestrator=openstack -e config_file=$TF_CONFIG_DIR/ziu_instances.yaml playbooks/ziu.yml

check_tf_active