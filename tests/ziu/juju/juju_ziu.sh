#!/bin/bash -x
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

export PATH=$PATH:/snap/bin
TF_CONFIG_DIR=${TF_CONFIG_DIR:-"$HOME/.tf"}
source /tmp/test.env

export CONTAINER_REGISTRY="$CONTAINER_REGISTRY_ORIGINAL"
export CONTRAIL_CONTAINER_TAG="$CONTRAIL_CONTAINER_TAG_ORIGINAL$TAG_SUFFIX"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}

CONTROLLERS_COUNT=`echo "$( echo $CONTROLLER_NODES | tr ',' ' ' )" | awk -F ' ' '{print NF}'`
analyticsdb_enabled=$(( $(juju status | cut -d " " -f1 | grep -q contrail-analyticsdb; echo $?) == 0 ))
status_nodes=$(( $CONTROLLERS_COUNT * (2 + $analyticsdb_enabled) ))

function ziu_status() {
    (( $(juju status | grep "$1" | wc -l) - $status_nodes ))
}

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

function sync_time() {
  local machine
  for machine in $(echo "$CONTROLLER_NODES $AGENT_NODES" | tr " " "\n" | sort -u) ; do
    scp $SSH_OPTIONS ${my_dir}/sync_time.sh $SSH_USER@$machine:/tmp/sync_time.sh
    ssh $SSH_OPTIONS $SSH_USER@$machine /tmp/sync_time.sh
  done
}

juju run-action contrail-controller/leader upgrade-ziu

if ! wait_cmd_success 10 60 "ziu_status \"ziu is in progress - stage\/done = 0\/None\"" ; then
    echo "ERROR: ziu have not started"
    exit 1
fi

juju config contrail-analytics image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
(( $analyticsdb_enabled )) && juju config contrail-analyticsdb image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
juju config contrail-agent image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
juju config contrail-openstack image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
juju config contrail-controller image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY

if ! wait_cmd_success 20 540 "ziu_status \"ziu is in progress - stage\/done = 5\/5\"" ; then
    echo "ERROR: ziu've got an error before stage 5"
    exit 1
fi
# wait a bit when all agents consume stage 5
sleep 60

for agent in $(juju status | grep -o "contrail-agent/[0-9]*"); do
    juju run-action --wait $agent upgrade
done

sync_time

if ! wait_cmd_success 20 30 "juju status | grep -q \"ziu\"" ; then
    echo "ERROR: ziu haven't finished"
    exit 1
fi

if ! wait_cmd_success 50 50 "juju status | grep -q \"waiting\|blocked\|maintenance\|unknown\"" ; then
    echo "ERROR: tf is not active after ziu"
    exit 1
fi

