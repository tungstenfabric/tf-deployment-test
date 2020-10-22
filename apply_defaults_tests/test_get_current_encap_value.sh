#!/bin/bash -ex

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"

source "$my_dir/test_functions.sh"

hello_my_friend

for machine in $CONTROLLER_NODES ; do
  node=machine
done

encap_before_test=$(python3 /apply_defaults_tests/get_encap_priority.py $node)

echo $encap_before_test

echo "test_get_current_encap_value: PASSED"

exit 0