#!/bin/bash -e
set -x

source /root/.tf/stack.env

# TODO: run tests
test_file="/apply_defaults_tests/test_get_current_encap_value.sh"
cat $test_file
sudo bash $test_file

# TODO: save logs


# TODO: check result and print some message
echo "INFO: tests finished"
