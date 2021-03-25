#!/bin/bash -eu

function run_ssh() {
  local user=$1	
  local addr=$2
  local ssh_key=${3:-''}
  local command=$4
  local ssh_opts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no'
  if [[ -n "$ssh_key" ]] ; then
    ssh_opts+=" -i $ssh_key"
  fi
  echo ------------------------- Running on $user@$addr -----------------------------------
  echo ---  Command: $command
  ssh ${user}@${addr} ${command}
  if [ $? -ne 0 ]
  then
     echo ===================== FAIL: ${command}
     echo Exiting
     exit 1
  else
     echo --------------------- Command ${command} finished successfull
  fi
}

function run_ssh_undercloud() {
  run_ssh $SSH_USER $mgmt_ip $ssh_private_key "$@"
}

function wait_ssh() {
  local user=$1	
  local addr=$2
  local ssh_key=${3:-''}
  local max_iter=${4:-120}
  local iter=0
  local ssh_opts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no'
  if [[ -n "$ssh_key" ]] ; then
    ssh_opts+=" -i $ssh_key"
  fi
  local tf=$(mktemp)
  sleep 60
  while ! scp $ssh_opts -B $tf ${user}@${addr}:/tmp/ ; do
    if (( iter >= max_iter )) ; then
      echo "Could not connect to VM $addr"
      exit 1
    fi
    echo "Waiting for VM $addr..."
    sleep 30
    ((++iter))
  done
  echo "Node is back!"
}

function reboot_and_wait_undercloud() {
  local ssh_opts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no'
  if [[ -n "$ssh_private_key" ]] ; then
    ssh_opts+=" -i $ssh_private_key"
  fi
  echo "Rebooting undercloud"
  ssh ${SSH_USER}@${mgmt_ip} 'sudo reboot' || true
  wait_ssh $SSH_USER $mgmt_ip $ssh_private_key
}

function reboot_and_wait_overcloud_node() {
  local ip=$1
  local user=${2:-'heat-admin'}
  local ssh_opts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no'
  echo "Rebooting overcloud node $ip"
  ssh ${user}@${ip} 'sudo reboot' || true
  wait_ssh $user $ip
}

function checkForVariable() {
  local env_var=$(declare -p "$1")
  if !  [[ -v $1 && $env_var =~ ^declare\ -x ]]; then
    echo "Error: Define $1 environment variable"
    exit 1
  fi
}

function add_variable() {
  local file=$1
  local var_name=$2
  local var_value=${3}
  sed -i "/^export $var_name/d" $file
  echo "export $var_name=\"$var_value\"" >>$file
}

function retry() {
    local -r -i max_attempts="$1"; shift
    local -i attempt_num=1
    until "$@"
    do
        if ((attempt_num==max_attempts))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $((attempt_num++))
        fi
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

