#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source "$my_dir/test_functions.sh"
source "$my_dir/test_common.sh"

# hello_my_friend

IFS=', ' read -r -a array_controller_nodes <<< "$CONTROLLER_NODES"
node=${array_controller_nodes[0]}
echo "node is $node"

encap_before_test=$(python3 /apply_defaults_tests/get_encap_priority.py $node)

echo "encap_before_test is $encap_before_test"

default_encap_priority="encapsulation = ['MPLSoUDP', 'MPLSoGRE', 'VXLAN']"
if [[ "$encap_before_test" != "$default_encap_priority" ]] ; then
  echo "WARNING: current encap_priority is not default $default_encap_priority"
  # exit 1
fi

# new_encap_priority="'MPLSoGRE', 'VXLAN', 'MPLSoUDP'"
new_encap_priority='MPLSoGRE'
if [[ "$encap_before_test" != "encapsulation = [$new_encap_priority]" ]] ; then
  new_encap_priority="VXLAN"
fi
echo "we begining set encap_priority = $new_encap_priority"
change_result=$(python3 /apply_defaults_tests/change_encap_priority.py $node $new_encap_priority)
echo "result of change_encap_priority is $change_result"

encap_after_change=$(python3 /apply_defaults_tests/get_encap_priority.py $node)
echo "encap_after_change is $encap_after_change"

if [[ "$encap_before_test" == "$encap_after_change" ]] ; then
  echo "ERROR: encap_priority was not changed by api"
  exit 1
fi

echo "test_get_current_encap_value: PASSED"

exit 0