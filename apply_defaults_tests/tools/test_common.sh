#!/bin/bash -ex

source /root/.tf/stack.env

export CONTROLLER_NODES="${CONTROLLER_NODES}"
export SSH_OPTIONS=${SSH_OPTIONS:-"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"}