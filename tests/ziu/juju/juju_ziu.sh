#!/bin/bash -e
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

export PATH=$PATH:/snap/bin
source /tmp/test.env

export CONTAINER_REGISTRY="$CONTAINER_REGISTRY_ORIGINAL"
export CONTRAIL_CONTAINER_TAG="$CONTRAIL_CONTAINER_TAG_ORIGINAL"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}

function ziu_status_for_pattern() {
    # juju 2.9.0 started to return similar messages in applications as in units - cur app section first
    if [[ $(juju status | grep -A 2000 "Unit *Workload" | grep "$1" | wc -l) != "$units_count" ]]; then
        return 1
    fi
    return 0
}

function juju_status_absent_pattern() {
    # juju 2.9.0 started to return similar messages in applications as in units - cur app section first
    if juju status | grep -A 2000 "Unit *Workload" | grep -q "$1" ; then
        return 1
    fi
    return 0
}

function wait_cmd_success() {
    local i=0
    while ! eval $3; do
        sleep $1
        printf "."
        i=$((i + 1))
        if (( i >= $2 )); then
            echo ''
            echo "ERROR: wait failed in $((i*$1))s"
            return 1
        fi
    done
    echo ''
    echo "INFO: done in $((i*$1))s"
    return 0
}

function sync_time() {
    local machine
    for machine in $(echo "$CONTROLLER_NODES $AGENT_NODES" | tr " " "\n" | sort -u) ; do
        scp $SSH_OPTIONS ${my_dir}/../../../common/scripts/sync_time.sh $SSH_USER@$machine:/tmp/sync_time.sh
        ssh $SSH_OPTIONS $SSH_USER@$machine /tmp/sync_time.sh
    done
}

echo "INFO: current env  $(date)"
env|sort
echo ''

controllers_count=$(echo $CONTROLLER_NODES | tr ',' ' ' | wc -w)
units_count=$controllers_count
if [[ ${LEGACY_ANALYTICS_ENABLE,,} == 'true' ]]; then
    units_count=$((3 * controllers_count))
fi
echo "INFO: Count of units in control plane = $units_count. Start ZIU...  $(date)"

juju run-action tf-controller/leader upgrade-ziu

if ! wait_cmd_success 10 60 "ziu_status_for_pattern \"ziu is in progress - stage\/done = 0\/None\"" ; then
    echo "ERROR: ziu have not started"
    exit 1
fi

echo "INFO: required units are in maintenance state. Update image tags...  $(date)"

juju config tf-analytics image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
if [[ ${LEGACY_ANALYTICS_ENABLE,,} == 'true' ]]; then
    juju config tf-analyticsdb image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
fi
juju config tf-agent image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
juju config tf-openstack image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY
juju config tf-controller image-tag=$CONTRAIL_CONTAINER_TAG docker-registry=$CONTAINER_REGISTRY

echo "INFO: wait for control plane done  $(date)"

if ! wait_cmd_success 20 540 "ziu_status_for_pattern \"ziu is in progress - stage\/done = 5\/5\"" ; then
    echo "ERROR: ziu've got an error before stage 5"
    exit 1
fi
# wait a bit when all agents consume stage 5
sleep 60

echo "INFO: Control plane is done. Run upgrade for agents...  $(date)"

for agent in $(juju status | grep -o "tf-agent/[0-9]*"); do
    juju run-action --wait $agent upgrade
done

if ! wait_cmd_success 20 40 "juju_status_absent_pattern ziu" ; then
    echo "ERROR: ziu haven't finished"
    exit 1
fi

echo "INFO: agents are ready. Sync time and wait for active state  $(date)"

sync_time

if ! wait_cmd_success 60 40 "juju_status_absent_pattern \"waiting\|blocked\|maintenance\|unknown\"" ; then
    echo "ERROR: tf is not active after ziu"
    exit 1
fi

echo "INFO: ZIU is done  $(date)"
