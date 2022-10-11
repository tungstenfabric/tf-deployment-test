
function collect_contrail_version() {
    local user=$1
    local output_file=$2
    shift
    shift
    local nodelist=("$@")
    local ip=''

    for ip in "${nodelist[@]}"; do
        echo "-------- CONTRAIL CONTAINERS ON THE NODE $ip ---------" >> $output_file
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user@$ip "sudo podman ps --all | grep contrail" >> $output_file
        echo "-------- KERNEL VROUTER MODULE ON THE NODE $ip ---------" >> $output_file
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user@$ip "sudo modinfo vrouter || true" >> $output_file
    done
}


