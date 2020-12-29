
function collect_contrail_version() {
    local nodelist=$1
    local user=$2
    local output_file=$3

    for ip in $nodelist; do
        echo "-------- CONTRAIL CONTAINERS ON THE NODE $ip ---------" >> logs/$output_file
        ssh $user@$ip "sudo podman ps | grep contrail" >> logs/$output_file
    done

}

