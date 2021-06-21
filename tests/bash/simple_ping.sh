#!/bin/bash
# all deployers, k8s orchestrator smoke test

function create_busybox() {
  local pod_name=$1

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
    name: $pod_name
spec:
    containers:
    - name: busybox
      image: busybox
      imagePullPolicy: IfNotPresent
      args:
      - sleep
      - infinity
EOF
}

function is_running() {
  local pod_name=$1
  [ $(kubectl get pod $pod_name -o jsonpath='{.status.phase}') == "Running" ]
}

function wait() {
  local check=$1
  local max_time=$2
  while [[ $max_time != 0 ]]; do
    if eval $check; then
      return 0
    fi
    sleep 1
    max_time=$((max_time-1))
  done
  return 1
}

function cleanup() {
  kubectl delete pod pingtest-sender
  kubectl delete pod pingtest-receiver
}

# Some deployers use k8s from home directory
PATH="$HOME:$PATH"
if ! which kubectl &>/dev/null; then
  echo "ERROR: there are no kubectl"
  exit 1
fi

create_busybox pingtest-sender
create_busybox pingtest-receiver

if ! wait "is_running pingtest-sender && is_running pingtest-receiver" 30; then
  echo "ERROR: created pods are not in the running state"
  cleanup
  exit 1
fi

receiver_ip=$(kubectl get pod pingtest-receiver -o jsonpath='{.status.podIP}')
if ! wait "kubectl exec pingtest-sender -- ping $receiver_ip -c1 &>/dev/null" 30; then
  echo "ERROR: ping failed"
  cleanup
  exit 1
fi

cleanup
