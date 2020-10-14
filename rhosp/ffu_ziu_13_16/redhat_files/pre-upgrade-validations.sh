#!/bin/bash
for VALIDATION in $(openstack action execution run tripleo.validations.list_validations '{"groups": ["pre-upgrade"]}' | jq ".result[] | .id")
do
  echo "=== Running validation: $VALIDATION ==="
  ID=$(openstack workflow execution create -f value -c ID tripleo.validations.v1.run_validation "{\"validation_name\": $VALIDATION}")
  while [ $(openstack workflow execution show $ID -f value -c State) == "RUNNING" ]
  do
    sleep 1
  done
  echo ""
  openstack workflow execution output show $ID | jq -r ".stdout"
  echo ""
done
