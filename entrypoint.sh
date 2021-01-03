#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
set -a
source /input/test.env
set +a
eval export $(sed 's/=.*//' /input/test.env )

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
testr list-tests | python3 filter_tests.py > test_list
echo "List of tests:"
cat test_list
testr run --load-list test_list

# show results
testr last --subunit
testr last --subunit | subunit2junitxml -f -o report.xml
