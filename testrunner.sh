#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"

env_opts=""
env_opts+=" --env SSH_USER=$(whoami)"
env_opts+=" --env SSH_HOST=$(hostname -i | awk '{print $1}')"
env_opts+=" --env CONTAINER_REGISTRY_ORIGINAL=$CONTAINER_REGISTRY_ORIGINAL"
env_opts+=" --env CONTRAIL_CONTAINER_TAG_ORIGINAL=$CONTRAIL_CONTAINER_TAG_ORIGINAL"

vol_opts=""
vol_opts+=" -v ${TF_CONFIG_DIR}:/root/.tf"
vol_opts+=" -v $HOME/.ssh/id_rsa:/root/.ssh/id_rsa"

# NOTE: to be able to have sources locally that will be executed
# user can clone this repo from script dir and it will be used as a source code
if [ -d $scriptdir/tf-deployment-test ]; then
  vol_opts+=" -v $scriptdir/tf-deployment-test:/tf-deployment-test"
fi

sudo docker run --rm -i $vol_opts $env_opts $TF_DEPLOYMENT_TEST_IMAGE || res=1

# TODO: collect logs

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests passed"
fi

exit $res
