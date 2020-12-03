#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
set -a
source /input/test.env
set +a

if [[ -z "$ORCHESTRATOR" || -z "$DEPLOYER" ]]; then
    echo "ERROR: ORCHESTRATOR and DEPLOYER must be set in stack.env"
    exit 1
fi

cd $scriptdir

if [[ ! -d ".testrepository" ]]; then
    testr init
fi

DEPLOYER_TAG=$DEPLOYER
ORCHESTRATOR_TAG=$ORCHESTRATOR
# TODO: will be renamed to hybrid
if [[ $ORCHESTRATOR == 'all' ]] ; then
    ORCHESTRATOR_TAG='hybrid'
fi
echo "Testing with deployment tag: ${DEPLOYMENT_TEST_TAGS}"
# get list of tests
# we filter the list by deployer, orchestrator, and additional if needed
# TODO: there can be several DEPLOYMENT_TEST_TAGS, no we support one only
testr list-tests | grep -e "\[.*${DEPLOYER_TAG}" -e "\[.*all-deployers" | grep -e "\[.*${ORCHESTRATOR_TAG}" -e "\[.*all-orchestrators" | grep -e "\[.*${DEPLOYMENT_TEST_TAGS}" > test_list
cat test_list
testr run --load-list test_list

# TODO: Add subunit logs:
testr last --subunit | subunit2junitxml -f -o report.xml
