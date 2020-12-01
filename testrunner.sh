#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

# env file must not contain any quotes for value
# docker treat quotes as a part of value
TEST_ENV_FILE=$TF_CONFIG_DIR/test.env

echo "INFO: create test.env"
rm -f $TEST_ENV_FILE
touch $TEST_ENV_FILE
if [ -f $TF_CONFIG_DIR/stack.env ]; then
  set -a
  source $TF_CONFIG_DIR/stack.env
  set +a
  cat $TF_CONFIG_DIR/stack.env | sed -e 's/="\(.*\)/=\1/g' -e 's/"$//g' | sed -e "s/='\(.*\)/=\1/g" -e "s/'$//g" > $TEST_ENV_FILE
fi
echo "CONTAINER_REGISTRY_ORIGINAL=$CONTAINER_REGISTRY_ORIGINAL" >> $TEST_ENV_FILE
echo "CONTRAIL_CONTAINER_TAG_ORIGINAL=$CONTRAIL_CONTAINER_TAG_ORIGINAL" >> $TEST_ENV_FILE
echo "SSH_USER=$(whoami)" >> $TEST_ENV_FILE
echo "SSH_HOST=$(hostname -i | awk '{print $1}')" >> $TEST_ENV_FILE
cat $TEST_ENV_FILE

vol_opts=" -v $TEST_ENV_FILE:/input/test.env"
vol_opts+=" -v $HOME/.ssh/id_rsa:/root/.ssh/id_rsa"

# NOTE: to be able to have sources locally that will be executed
# user can clone this repo from script dir and it will be used as a source code
if [ -d $scriptdir/tf-deployment-test ]; then
  vol_opts+=" -v $scriptdir/tf-deployment-test:/tf-deployment-test"
fi

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"
sudo docker run --rm -i $vol_opts --env-file $TEST_ENV_FILE $TF_DEPLOYMENT_TEST_IMAGE || res=1

# TODO: collect logs

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests passed"
fi

exit $res
