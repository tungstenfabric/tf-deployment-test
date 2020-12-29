
function collect_contrail_version() {
    local nodelist=$1
    local user=$2
    local output_file=$3
    local ip=''

    for ip in $nodelist; do
        echo "-------- CONTRAIL CONTAINERS ON THE NODE $ip ---------" >> logs/ziu/$output_file
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user@$ip "sudo podman ps --all | grep contrail" >> logs/ziu/$output_file
        echo "-------- KERNEL VROUTER MODULE ON THE NODE $ip ---------" >> logs/ziu/$output_file
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $user@$ip "sudo modinfo vrouter || true" >> logs/ziu/$output_file
    done

}

