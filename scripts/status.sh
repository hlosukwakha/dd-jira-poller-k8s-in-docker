#!/usr/bin/env bash
set -euo pipefail

source /workspace/scripts/lib.sh
ensure_kind_access

echo "== Nodes =="
kubectl get nodes -o wide || true
echo
echo "== Datadog (namespace: datadog) =="
kubectl -n datadog get pods -o wide || true
echo
echo "== Jira poller (namespace: jira-poller) =="
kubectl -n jira-poller get all -o wide || true
