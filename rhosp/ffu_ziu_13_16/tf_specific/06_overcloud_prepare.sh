ansible-playbook -i inventory.yaml $my_dir/../redhat_files/playbook-nics-vlans.yaml
ansible-playbook -i inventory.yaml -l overcloud_Compute $my_dir/../tf-specific/playbook-nics-vhost0.yaml

