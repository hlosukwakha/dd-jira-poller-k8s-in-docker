#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="/workspace/.kube/config"
mkdir -p /workspace/.kube

: "${KIND_CLUSTER_NAME:=dd-jira-kind}"
: "${DD_SITE:=datadoghq.eu}"
: "${DATADOG_API_KEY:?Missing DATADOG_API_KEY in .env}"
: "${JIRA_BASE_URL:?Missing JIRA_BASE_URL in .env}"
: "${JIRA_EMAIL:?Missing JIRA_EMAIL in .env}"
: "${JIRA_API_TOKEN:?Missing JIRA_API_TOKEN in .env}"
: "${POLL_INTERVAL_SECONDS:=30}"
: "${JIRA_JQL:=assignee = currentUser() ORDER BY updated DESC}"

echo "[1/6] Creating kind cluster: ${KIND_CLUSTER_NAME}"
if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
  echo "kind cluster already exists: ${KIND_CLUSTER_NAME}"
else
  kind create cluster --name "${KIND_CLUSTER_NAME}" --config /workspace/k8s/kind-config.yaml --kubeconfig "${KUBECONFIG}"
fi
source /workspace/scripts/lib.sh
ensure_kind_access

# Ensure this tooling container can reach the kind control-plane container
docker network connect kind "$(hostname)" >/dev/null 2>&1 || true

# Re-export kubeconfig using the internal API endpoint (control-plane:6443)
kind export kubeconfig --name "${KIND_CLUSTER_NAME}" --kubeconfig "${KUBECONFIG}" --internal


echo "[2/6] Installing Datadog Agent via Helm (namespace: datadog)"
kubectl get ns datadog >/dev/null 2>&1 || kubectl create ns datadog

kubectl -n datadog create secret generic datadog-secret \
  --from-literal api-key="${DATADOG_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add datadog https://helm.datadoghq.com >/dev/null
helm repo update >/dev/null

helm upgrade --install datadog datadog/datadog \
  --namespace datadog \
  -f /workspace/datadog/values.yaml \
  --set datadog.site="${DD_SITE}" \
  --set datadog.clusterName="${KIND_CLUSTER_NAME}" \
  --wait

echo "[3/6] Building app image (jira-poller:0.1.0)"
docker build -t jira-poller:0.1.0 -f /workspace/docker/jira-poller/Dockerfile /workspace

echo "[4/6] Loading image into kind"
kind load docker-image jira-poller:0.1.0 --name "${KIND_CLUSTER_NAME}"

echo "[5/6] Deploying jira-poller to Kubernetes"
kubectl apply -f /workspace/k8s/jira-poller/namespace.yaml

kubectl -n jira-poller create secret generic jira-poller-jira \
  --from-literal JIRA_BASE_URL="${JIRA_BASE_URL}" \
  --from-literal JIRA_EMAIL="${JIRA_EMAIL}" \
  --from-literal JIRA_API_TOKEN="${JIRA_API_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f /workspace/k8s/jira-poller/configmap.yaml

# Patch configmap values from .env so you don't have to edit YAML
kubectl -n jira-poller patch configmap jira-poller-config --type merge -p "$(cat <<EOF
{
  "data": {
    "POLL_INTERVAL_SECONDS": "${POLL_INTERVAL_SECONDS}",
    "JIRA_JQL": "${JIRA_JQL}"
  }
}
EOF
)"

kubectl apply -f /workspace/k8s/jira-poller/deployment.yaml

echo "[6/6] Waiting for rollout"
kubectl -n jira-poller rollout status deploy/jira-poller --timeout=180s

echo "Done."
echo "Try:"
echo "  make status"
echo "  make logs"
