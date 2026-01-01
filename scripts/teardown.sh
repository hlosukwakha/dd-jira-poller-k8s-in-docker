#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="/workspace/.kube/config"
: "${KIND_CLUSTER_NAME:=dd-jira-kind}"

echo "Deleting kind cluster: ${KIND_CLUSTER_NAME}"
if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
  kind delete cluster --name "${KIND_CLUSTER_NAME}"
else
  echo "Cluster not found: ${KIND_CLUSTER_NAME}"
fi
