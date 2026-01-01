#!/usr/bin/env bash
set -euo pipefail

ensure_kind_access() {
  export KUBECONFIG="/workspace/.kube/config"
  mkdir -p /workspace/.kube

  : "${KIND_CLUSTER_NAME:=dd-jira-kind}"

  # This ctl container is ephemeral; attach it to the kind network every run.
  local cid
  cid="$(cat /etc/hostname)"

  # The 'kind' network exists once the cluster exists.
  docker network connect kind "$cid" >/dev/null 2>&1 || true

  # Ensure kubeconfig uses the internal API endpoint (control-plane:6443)
  kind export kubeconfig --name "${KIND_CLUSTER_NAME}" --kubeconfig "${KUBECONFIG}" --internal >/dev/null 2>&1 || true
}
