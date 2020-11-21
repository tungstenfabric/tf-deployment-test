#!/bin/bash -e

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"

env_opts=""
env_opts+=" --env JUMPHOST_HOST_USER=$(whoami)"
env_opts+=" --env JUMPHOST_HOST_ADDR=$(hostname -i | awk '{print $1}')"

vol_opts=""
vol_opts+=" -v ${TF_CONFIG_DIR}:/root/.tf"
vol_opts+=" -v $HOME/.ssh:/root/.ssh"

sudo docker run --rm -i $vol_opts $env_opts $TF_DEPLOYMENT_TEST_IMAGE || res=1

# TODO: collect logs

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests succeeded"
fi
