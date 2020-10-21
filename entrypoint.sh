#!/bin/bash -e
set -x

source /root/.tf/stack.env

# TODO: run tests
echo "ls -la"
ls -la
sudo ./apply_defaults_tests/test_apply_defaults_true.sh

# TODO: save logs


# TODO: check result and print some message
echo "INFO: tests finished"
