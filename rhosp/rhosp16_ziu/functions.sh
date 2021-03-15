
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

function update_contrail_preparation() {
    local nodelist=("$@")
    local ip=''
    SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    CONTRAIL_IMAGE_PREFIX=${CONTRAIL_IMAGE_PREFIX:-'contrail-'}
    STOP_CONTAINERS=${STOP_CONTAINERS:-'contrail_config_api contrail_analytics_api'}
    STOP_CONTAINERS_ESC=$(echo $STOP_CONTAINERS | sed -e 's/ /\\ /g')

    for ip in "${nodelist[@]}"; do
        echo "-------- node: ${ip}  Preparation for ZIU update"
        scp ${SSH_OPTIONS} ~/tripleo-heat-templates/tools/contrail/pull_new_contrail_images.sh ~/tripleo-heat-templates/tools/contrail/stop_contrail_api_containers.sh ${SSH_USER}@${ip}:
        echo "--- node: ${ip}  Pulling new container images:"
        ssh ${SSH_OPTIONS} ${SSH_USER}@${ip} CONTRAIL_IMAGE_PREFIX=${CONTRAIL_IMAGE_PREFIX} CONTRAIL_NEW_IMAGE_TAG=${CONTRAIL_NEW_IMAGE_TAG} ./pull_new_contrail_images.sh
    done

    for ip in "${nodelist[@]}"; do
        echo "--- node: ${ip}  Stoping containers:"
        ssh ${SSH_OPTIONS} ${SSH_USER}@${ip} STOP_CONTAINERS="${STOP_CONTAINERS_ESC}" ./stop_contrail_api_containers.sh 
    done

}


