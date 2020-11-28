#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"

echo "INFO: create test.env"
test_env=$TF_CONFIG_DIR/test.env
rm -f $TF_CONFIG_DIR/test.env
touch $TF_CONFIG_DIR/test.env
if [ -f $TF_CONFIG_DIR/stack.env ]; then
  cat $TF_CONFIG_DIR/stack.env > $TF_CONFIG_DIR/test.env
fi
echo "CONTAINER_REGISTRY_ORIGINAL=$CONTAINER_REGISTRY_ORIGINAL" >> $TF_CONFIG_DIR/test.env
echo "CONTRAIL_CONTAINER_TAG_ORIGINAL=$CONTRAIL_CONTAINER_TAG_ORIGINAL" >> $TF_CONFIG_DIR/test.env
echo "SSH_USER=$(whoami)" >> $TF_CONFIG_DIR/test.env
echo "SSH_HOST=$(hostname -i | awk '{print $1}')" >> $TF_CONFIG_DIR/test.env
cat $TF_CONFIG_DIR/test.env

vol_opts=" -v $TF_CONFIG_DIR/test.env:/input/test.env"
vol_opts+=" -v $HOME/.ssh/id_rsa:/root/.ssh/id_rsa"

# NOTE: to be able to have sources locally that will be executed
# user can clone this repo from script dir and it will be used as a source code
if [ -d $scriptdir/tf-deployment-test ]; then
  vol_opts+=" -v $scriptdir/tf-deployment-test:/tf-deployment-test"
fi

sudo docker run --rm -i $vol_opts --env-file $TF_CONFIG_DIR/test.env $TF_DEPLOYMENT_TEST_IMAGE || res=1

# TODO: collect logs

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests passed"
fi

exit $res
