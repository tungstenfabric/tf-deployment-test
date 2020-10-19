#!/bin/bash -e

set -x
TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

TF_DEPLOYMENT_TEST_IMAGE="${TF_DEPLOYMENT_TEST_IMAGE:-${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}}"
sudo docker run -i -v ${TF_CONFIG_DIR}:/root/.tf --env TF_HOST_USER="$(whoami)" --env TF_HOST_ADDR="$(hostname -I | cut -d' ' -f1)" --env TF_HOST_KEY="$(cat ~/.ssh/id_rsa)" $TF_DEPLOYMENT_TEST_IMAGE || res=1

# TODO: collect logs

if [[ "$res" == 1 ]]; then
  echo "ERROR: Tests failed"
else
  echo "INFO: tests succeeded"
fi
