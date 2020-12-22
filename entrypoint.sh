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

echo "Testing with deployment tag: ${DEPLOYMENT_TEST_TAGS}"
# get list of tests
# we filter the list by deployer, orchestrator, and additional if needed
echo "ORCHESTRATOR_TAG=$ORCHESTRATOR" > /tmp/test_list
echo "DEPLOYER_TAG=$DEPLOYER" >> /tmp/test_list
echo "DEPLOYMENT_TEST_TAGS=${DEPLOYMENT_TEST_TAGS}" >> /tmp/test_list
testr list-tests >> /tmp/test_list
python3 filter_tests.py
echo "List of tests:"
cat /tmp/test_list_filterd
testr run --load-list /tmp/test_list_filtered

# TODO: Add informative logs:
# testr last --subunit | subunit2junitxml -f -o report.xml
