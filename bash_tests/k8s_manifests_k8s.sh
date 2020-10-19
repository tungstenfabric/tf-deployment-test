#!/bin/bash
# k8s manifests deployer, k8s orchestrator smoke test

agent_pod_phase=$(kubectl get pods --all-namespaces -o custom-columns==NAME:.metadata.name,STATUS:.status.phase | grep "contrail-agent" | head -1)
agent_pod=$(echo $agent_pod_phase | cut -d " " -f1)
agent_phase=$(echo $agent_pod_phase | cut -d " " -f2)
echo "Agent pod is: $agent_pod"
if [[ "$agent_phase" != "Running" ]] ; then
  echo "ERROR: agent pod $agent_pod is not in Running state" > /proc/self/fd/2
fi
