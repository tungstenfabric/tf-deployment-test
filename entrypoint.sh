#!/bin/bash

set -o errexit
set -o pipefail

scriptdir=$(realpath $(dirname "$0"))

set -a ; source /input/test.env ; set +a
eval export $(sed 's/=.*//' /input/test.env)
[[ "$DEBUG" != true ]] || set -x

if [[ -z "$ORCHESTRATOR" || -z "$DEPLOYER" ]]; then
    echo "ERROR: ORCHESTRATOR and DEPLOYER must be set in stack.env"
    exit 1
fi

cd $scriptdir

if [[ ! -d ".testrepository" ]]; then
    testr init
fi

echo "INFO: Testing with deployment tag: ${DEPLOYMENT_TEST_TAGS}"
# get list of tests
# we filter the list by deployer, orchestrator, and additional if needed
testr list-tests | python3 filter_tests.py > test_list
echo "INFO List of tests:"
cat test_list
testr run --load-list test_list

# show results
echo "INFO: last results"
testr last --subunit | subunit-trace
echo "INFO: generate report"
testr last --subunit | subunit2junitxml -o /output/logs/report.xml
