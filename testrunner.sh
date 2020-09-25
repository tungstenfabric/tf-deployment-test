#!/bin/bash

CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}

sudo docker run ${CONTAINER_REGISTRY}/tf-deployment-test:${CONTRAIL_CONTAINER_TAG}

echo tf-deployment-test/testrunner.sh finished