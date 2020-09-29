#!/bin/bash
TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}

CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

sudo docker run -v ${TF_CONFIG_DIR}/stack.env:/stack.env ${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}'


echo tf-deployment-test/testrunner.sh finished