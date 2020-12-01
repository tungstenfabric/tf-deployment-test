#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))

if [[ -z "$ORCHESTRATOR" || -z "$DEPLOYER" ]]; then
    echo "ERROR: ORCHESTRATOR and DEPLOYER must be set in stack.env"
    exit 1
fi

cd $scriptdir

if [[ ! -d ".testrepository" ]]; then
    testr init
fi
tests_tag="${DEPLOYER}-${ORCHESTRATOR}"
testr run "${tests_tag}|all-deployers|all-orchestrator"

# TODO: Add subunit logs:
#testr run --subunit ${tests_tag} | subunit2junitxml -f -o report.xml