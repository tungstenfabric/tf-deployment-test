#!/bin/bash -ex

source /root/.tf/stack.env

# TODO: run tests
test_file="/apply_defaults_tests/test_apply_defaults.sh"
sudo bash $test_file

# TODO: save logs

# TODO: check result and print some message
echo "INFO: tests finished"
