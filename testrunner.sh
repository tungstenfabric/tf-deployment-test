#!/bin/bash -e
set -o pipefail

export DEBUG=${DEBUG:-false}
[[ "$DEBUG" != true ]] || set -x

scriptdir=$(realpath $(dirname "$0"))

TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}
# ?_ORIGINAL params must be set for ZIU tests

TEST_ENV_FILE=$TF_CONFIG_DIR/test.env

echo "INFO: create test.env"
rm -f $TEST_ENV_FILE
touch $TEST_ENV_FILE
echo "DEBUG=$DEBUG" >> $TEST_ENV_FILE
if [ -f $TF_CONFIG_DIR/stack.env ]; then
  set -a ; source $TF_CONFIG_DIR/stack.env ; set +a
  cat $TF_CONFIG_DIR/stack.env >> $TEST_ENV_FILE
fi
echo "CONTAINER_REGISTRY_ORIGINAL=$CONTAINER_REGISTRY_ORIGINAL" >> $TEST_ENV_FILE
echo "CONTRAIL_CONTAINER_TAG_ORIGINAL=$CONTRAIL_CONTAINER_TAG_ORIGINAL" >> $TEST_ENV_FILE
echo "DEPLOYER_CONTAINER_REGISTRY_ORIGINAL=$DEPLOYER_CONTAINER_REGISTRY_ORIGINAL" >> $TEST_ENV_FILE
echo "CONTRAIL_DEPLOYER_CONTAINER_TAG_ORIGINAL=$CONTRAIL_DEPLOYER_CONTAINER_TAG_ORIGINAL" >> $TEST_ENV_FILE
echo "SSH_USER=$(whoami)" >> $TEST_ENV_FILE
phys_int=`ip route get 1 | grep -o 'dev.*' | awk '{print($2)}'`
echo "SSH_HOST=$(ip addr show dev $phys_int | grep 'inet ' | awk '{print $2}' | head -n 1 | cut -d '/' -f 1)" >> $TEST_ENV_FILE
echo "DEPLOYMENT_TEST_TAGS=$DEPLOYMENT_TEST_TAGS" >> $TEST_ENV_FILE

cat $TEST_ENV_FILE

vol_opts=" -v $TEST_ENV_FILE:/input/test.env"

vol_opts+=" -v $HOME/.ssh/id_rsa:/root/.ssh/id_rsa"

if [[ "${SSL_ENABLE,,}" == 'true' ]]; then
  vol_opts+=" -v /etc/contrail/ssl:/etc/contrail/ssl"
fi

mkdir -p $scriptdir/output/logs
vol_opts+=" -v $scriptdir/output:/output"

# NOTE: to be able to have sources locally that will be executed
# user can clone this repo from script dir and it will be used as a source code
if [ -d $scriptdir/tf-deployment-test ]; then
  vol_opts+=" -v $scriptdir/tf-deployment-test:/tf-deployment-test"
fi

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"
sudo docker pull $TF_DEPLOYMENT_TEST_IMAGE

echo "INFO: command to run: sudo docker run --privileged=true --rm=true -t $vol_opts --network host $TF_DEPLOYMENT_TEST_IMAGE"
sudo docker run --privileged=true --rm=true -t $vol_opts --network host $TF_DEPLOYMENT_TEST_IMAGE || res=1

pushd $scriptdir/output
tar -cvf $WORKSPACE/logs.tar logs
popd
gzip $WORKSPACE/logs.tar
mv $WORKSPACE/logs.tar.gz $WORKSPACE/logs.tgz

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests passed"
fi

exit $res
