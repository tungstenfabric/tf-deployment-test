#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))

build_opts="--build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8"
build_opts+=" --network host --no-cache --tag ${DEVENV_IMAGE} --tag ${CONTAINER_REGISTRY}/${DEVENV_IMAGE} $scriptdir"

sudo docker build $build_opts