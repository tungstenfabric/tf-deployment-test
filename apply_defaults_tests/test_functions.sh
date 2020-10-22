#!/bin/bash

fmy_file="${BASH_SOURCE[0]}"
fmy_dir="$(dirname $fmy_file)"

function hello_my_friend() {
  echo "Step 1: Hello Alex!"
  return 0
}