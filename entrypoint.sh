#!/bin/bash -e
set -x

source /root/.tf/stack.env

echo "pwd is $(pwd)"
ls -la
my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
echo "my_file is $my_file and my_dir is $my_dir (expected apply_defaults_tests)"

# TODO: run tests
echo "ls -la"
ls -la
cat /apply_defaults_tests/test_apply_defaults_true.sh
sudo bash /apply_defaults_tests/test_apply_defaults_true.sh

# TODO: save logs


# TODO: check result and print some message
echo "INFO: tests finished"
