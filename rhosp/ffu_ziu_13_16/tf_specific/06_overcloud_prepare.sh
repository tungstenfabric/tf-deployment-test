ansible-playbook -i inventory.yaml $my_dir/../tf_specific/playbook-nics-vlans.yaml
ansible-playbook -i inventory.yaml -l overcloud_Compute $my_dir/../tf_specific/playbook-nics-vhost0.yaml

