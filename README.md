# dd-jira-poller-k8s-in-docker

[![Docker](https://img.shields.io/badge/Docker-Container%20Runtime-2496ED)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-326CE5)](https://kubernetes.io/)
[![kind](https://img.shields.io/badge/kind-Kubernetes%20in%20Docker-3C5A99)](https://kind.sigs.k8s.io/)
[![Helm](https://img.shields.io/badge/Helm-Package%20Manager-0F1689)](https://helm.sh/)
[![Python](https://img.shields.io/badge/Python-3.12%2B-blue)](https://www.python.org/)
[![requests](https://img.shields.io/badge/requests-HTTP%20Client-2A6DB3)](https://requests.readthedocs.io/)
[![ddtrace](https://img.shields.io/badge/ddtrace-APM%20Tracing-632CA6)](https://docs.datadoghq.com/tracing/trace_collection/)
[![Datadog](https://img.shields.io/badge/Datadog-Logs%20%7C%20Metrics%20%7C%20Traces-632CA6)](https://www.datadoghq.com/)
[![Jira](https://img.shields.io/badge/Jira-Issue%20Tracking-0052CC)](https://www.atlassian.com/software/jira)

A **fully containerized demo** that runs a **Kubernetes cluster inside Docker** (via **kind**), deploys a **Python Jira poller** that queries Jira every **30 seconds**, and ships **Kubernetes + container + application logs, metrics, and traces** to **Datadog Cloud**.

---

## Blog-style overview

Most “observability demos” stop at a single container. Real teams, however, operate with orchestration, service-to-service traffic, deployment rollouts, and noisy failure modes. This project gives you a compact but realistic sandbox where you can:

- run Kubernetes locally without a VM-heavy setup,
- deploy an app that periodically calls an external SaaS API (Jira),
- instrument that app with traces + custom metrics,
- collect cluster signals (nodes/pods/containers) and application logs,
- and validate everything end-to-end in Datadog.

The result is a practical reference repo you can use to prove a full telemetry pipeline—from a pod, through an Agent, into Datadog—before applying the same patterns to production clusters.

---

## Problem statement

**Goal:** Provide a repeatable, local environment where you can demonstrate and validate end-to-end observability for a Kubernetes workload.

**What it must do:**
1. Start a Kubernetes cluster **inside Docker**.
2. Deploy an application that queries **Jira every 30 seconds**.
3. Export:
   - application **logs** (stdout/stderr),
   - application **metrics** (DogStatsD),
   - application **traces** (APM),
   - Kubernetes and container **infrastructure telemetry**,
   to **Datadog Cloud**.

**Why this matters:**
- You can test dashboards/monitors and agent settings locally.
- You can reproduce tricky networking / DNS / hostPort issues that often appear only in containerized clusters.
- You can iterate quickly without touching production.

---

## Architecture

```mermaid
flowchart LR
  subgraph Host[Your machine]
    DC[Docker Engine]
    DD[Datadog Cloud]
  end

  subgraph Tools[Tooling container (docker-compose service: ctl)]
    K[kind / kubectl / helm]
  end

  subgraph Kind[Kind cluster (Kubernetes nodes = Docker containers)]
    subgraph Node[Single node]
      A[Datadog Agent (DaemonSet)]
      P[Python jira-poller (Deployment)]
    end
  end

  K -->|creates| Kind
  P -->|HTTP| Jira[Jira Cloud/Server]
  P -->|traces (8126)| A
  P -->|metrics (8125)| A
  P -->|stdout logs| A
  A -->|telemetry| DD
```

---

## Technology stack

| Technology | What it does here |
|---|---|
| **Docker** | Runs everything locally; also hosts the kind “node” container. |
| **kind** | Creates a Kubernetes cluster where nodes are Docker containers. |
| **Kubernetes** | Schedules the Jira poller and the Datadog Agent. |
| **Helm** | Installs/upgrades the Datadog Agent chart. |
| **Python** | Implements the Jira poller. |
| **requests** | Calls Jira REST APIs. |
| **ddtrace** | Creates APM spans for each polling cycle and injects trace context into logs. |
| **DogStatsD** | Sends custom metrics (issue_count, latency, success/failure). |
| **Datadog Agent** | Collects logs/metrics/traces and forwards them to Datadog Cloud. |
| **Datadog Cloud** | Dashboards, traces, log search, and alerting. |

---

## “Dataset” description (what data this project produces)

This project does not ship with a traditional ML dataset. Instead, it produces an **observability dataset** made of:

### 1) Jira data (external)
- Search responses from Jira (e.g., issue count, sample issue keys).
- This is retrieved at runtime via Jira REST API using your credentials and JQL.

### 2) Telemetry data (generated locally)
- **Logs**: JSON logs from the poller (success/error events, sample issue keys).
- **Metrics**: custom DogStatsD metrics such as:
  - `jira.poll.issue_count` (gauge)
  - `jira.poll.latency_ms` (histogram)
  - `jira.poll.success` / `jira.poll.failure` (counters)
- **Traces**: APM spans (e.g., `jira.poll`) per polling cycle.
- **Infrastructure signals**: pod/container/node telemetry from the Datadog Agent.

All of the above becomes your “dataset” for dashboards, monitors, and troubleshooting exercises.

---

## Who can benefit from this project

- **SRE / Platform / DevOps engineers** who need a local, repeatable sandbox for Kubernetes observability.
- **Cloud engineers** validating Datadog Agent configuration, hostPorts, log collection, and APM wiring.
- **Teams onboarding to Datadog** that want a working end-to-end example before production rollout.
- **Engineers building internal demos** for “logs, metrics, traces” fundamentals in Kubernetes.

---

## Prerequisites

- Docker (Docker Desktop or Linux Docker Engine)
- A Datadog account + Datadog API key
- Jira credentials:
  - `JIRA_BASE_URL` (e.g., `https://your-domain.atlassian.net`)
  - `JIRA_EMAIL`
  - `JIRA_API_TOKEN` (Jira Cloud API token)

---

## How to clone and run

### 1) Clone

```bash
git clone <YOUR_REPO_URL_HERE>
cd dd-jira-poller-k8s-in-docker
```

### 2) Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and set at least:
- `DATADOG_API_KEY`
- `DD_SITE` (e.g., `datadoghq.eu` or `datadoghq.com`)
- `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`
- (Optional) `JIRA_JQL`
- (Optional) `POLL_INTERVAL_SECONDS` (default 30)

### 3) Start everything

```bash
make up
```

### 4) Validate

```bash
make status
make logs
```

### 5) Tear down

```bash
make down
```

---

## Sample Datadog dashboard (included)

A starter dashboard JSON is included to help you validate:
- poll success/failure and latency,
- issue count returned,
- pod CPU/memory,
- recent logs for the poller.

**File:** `datadog-dashboard-dd-jira-poller.json`

### Import via Datadog UI
1. In Datadog, go to **Dashboards** → **New Dashboard**.
2. Choose **Import Dashboard JSON** (or open the JSON editor).
3. Paste the contents of `datadog-dashboard-dd-jira-poller.json`.
4. Save, then adjust template variables/tags if needed (`service`, `env`, `kube_cluster_name`, `kube_namespace`).

### Import via Datadog API
```bash
# EU: https://api.datadoghq.eu | US: https://api.datadoghq.com
export DD_SITE="https://api.datadoghq.eu"
export DD_API_KEY="..."
export DD_APP_KEY="..."

curl -sS -X POST "$DD_SITE/api/v1/dashboard"   -H "DD-API-KEY: $DD_API_KEY"   -H "DD-APPLICATION-KEY: $DD_APP_KEY"   -H "Content-Type: application/json"   --data-binary @datadog-dashboard-dd-jira-poller.json
```

---

## Troubleshooting

### 1) `kubectl` cannot reach the cluster from the tooling container
If you see errors like:
- `connection refused` to `127.0.0.1:<port>` or
- `lookup <cluster>-control-plane … no such host`

This indicates the ephemeral `ctl` container is not connected to the `kind` Docker network, or your kubeconfig is pointing to a host-only endpoint.

**Fix:** Ensure each script attaches the running tooling container to the `kind` network and exports an internal kubeconfig (`kind export kubeconfig --internal`).

### 2) Jira API returns `410 Gone` for `/rest/api/3/search`
Some Jira Cloud tenants return **410 Gone** for the legacy endpoint. Use the newer endpoint:
- `/rest/api/3/search/jql`

If you see 410 errors, update the app accordingly and redeploy the image to the cluster.

### 3) No data in Datadog
- Confirm `DATADOG_API_KEY` and `DD_SITE` are correct.
- Check Agent pods in `datadog` namespace.
- Confirm the poller pods are running and emitting logs.
- Verify the custom metric names match the dashboard JSON.

---

## Project contents

- `docker/ctl/` — tooling container (kind/kubectl/helm + Docker CLI)
- `k8s/` — Kubernetes manifests (kind config, app namespace/deployment)
- `datadog/` — Datadog Helm values
- `app/` — Python Jira poller source
- `scripts/` — bootstrap/teardown/status/log helpers
- `datadog-dashboard-dd-jira-poller.json` — sample dashboard JSON

---

## Security notes

- Do not commit `.env` or any Jira/Datadog secrets.
- Prefer API keys with least privilege necessary.

---

## License

MIT (see `LICENSE`).
