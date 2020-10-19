#!/bin/bash -e
set -x
if [[ -f /root/.tf/stack.env ]] ; then
    set -a
    source /root/.tf/stack.env
    set +a
fi
if [[ -z "$ORCHESTRATOR" || -z "$DEPLOYER" ]]; then
    echo "ERROR: ORCHESTRATOR and DEPLOYER must be set in stack.env"
    exit 1
fi
export WORKSPACE=/tf-deployment-test
cd $WORKSPACE
if [[ ! -d "$WORKSPACE/.testrepository" ]]; then
    testr init
fi
tests_tag="${ORCHESTRATOR}_and_${DEPLOYER}"
testr run --subunit ${tests_tag}

tail -f /dev/null