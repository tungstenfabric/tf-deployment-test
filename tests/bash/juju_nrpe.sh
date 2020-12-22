#!/bin/bash

check_list=$(juju run-action --wait nrpe/leader list-nrpe-checks | grep check-check | awk '{print$1}' | cut -f1 -d":")
for check_name in $check_list ; do
    check_result=$(juju run-action --wait nrpe/leader run-nrpe-check name=$check_name --format json)
    check_status=$(echo "$check_result" | jq '.[]["status"]' | sed 's/"//g')
    if [[ $check_status != 'completed' ]] ; then
        echo "ERROR: nrpe check $check_name $check_status"
        err_message=$(echo "$check_result" | jq '.[]["message"]')
        echo "err_message: $err_message"
    fi
done
