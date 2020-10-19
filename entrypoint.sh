#!/bin/bash -e
my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

if [[ -f /root/.tf/stack.env ]] ; then
    source=/root/.tf/stack.env
fi

export ORCHESTRATOR=${ORCHESTRATOR:=kubernetes}
export WORKSPACE=$my_dir
source /env/bin/activate
cd $WORKSPACE
if [[ ! -d "$WORKSPACE/.testrepository" ]]; then
    testr init
fi

tests_tag="${ORCHESTRATOR}_and_${DEPLOYER}"
testr run --subunit ${tests_tag}
    