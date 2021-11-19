ansible-playbook -i inventory.yaml -l overcloud_Compute $my_dir/../tf_specific/playbook-nics-vhost0.yaml
ansible-playbook -i inventory.yaml -l overcloud_ContrailDpdk $my_dir/../tf_specific/playbook-nics-vhost0.yaml
