#!/bin/bash -x
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"$HOME/.tf"}
source /tmp/test.env

export CONTAINER_REGISTRY="$CONTAINER_REGISTRY_ORIGINAL"
export CONTRAIL_CONTAINER_TAG="$CONTRAIL_CONTAINER_TAG_ORIGINAL$TAG_SUFFIX"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}

echo "export SSH_USER=$(whoami)" >> ziu.sh
echo "export CONTRAIL_NEW_IMAGE_TAG='nightly'" >> ziu.sh

function wait_cmd_success() {
    i=0
    while ! eval $3; do
        sleep $1
        printf "."
        i=$((i + 1))
        if (( i >= $2 )); then
            echo -e "\nERROR: wait failed in $((i*$1))s"
            return 1
        fi
    done
    echo -e "\nINFO: done in $((i*$1))s"
    return 0
}

function check_tf_active() {
  local machine
  local line=
  for machine in $(echo "$AGENT_NODES,$CONTROLLER_NODES" | sed "s/,/ /g"); do
    if ! ssh $SSH_OPTIONS $machine "command -v contrail-status" 2>/dev/null ; then
      return 1
    fi
    for line in $(ssh $SSH_OPTIONS $machine "sudo contrail-status" 2>/dev/null | egrep ": " | grep -v "WARNING" | awk '{print $2}'); do
      if [ "$line" != "active" ] && [ "$line" != "backup" ] ; then
        return 1
      fi
    done
  done
  return 0
}
if [ "$OPENSTACK_VERSION" == "queens" ]; then
    RHOSP_DIR="rhosp13_ziu"
elif [ "$OPENSTACK_VERSION" == "train" ]; then
    RHOSP_DIR="rhosp16_ziu"
fi

./$my_dir/../../../rhosp/$RHOSP_DIR/run.sh

if ! wait_cmd_success 300 120 "check_tf_active" ; then
    echo "ERROR: tf is not active after ziu"
    exit 1
fi
