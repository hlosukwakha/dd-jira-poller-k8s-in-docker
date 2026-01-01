# Kubernetes-in-Docker Jira Poller with Datadog Observability

This project spins up a **Kubernetes cluster inside Docker** (via **kind**), deploys:
- a **Python app** running as a Kubernetes Deployment that queries **Jira every 30 seconds**, and
- the **Datadog Agent (Helm chart)** to collect **logs, metrics, and traces** from:
  - the Kubernetes cluster (kubelet, KSM core, container metrics),
  - the application (APM traces + DogStatsD custom metrics),
  - the application logs (stdout/stderr → Datadog logs).

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

## Prerequisites

- Docker (Docker Desktop or Linux Docker Engine)
- A Datadog account + **Datadog API key**
- Jira credentials:
  - `JIRA_BASE_URL` (e.g., `https://your-domain.atlassian.net`)
  - `JIRA_EMAIL`
  - `JIRA_API_TOKEN` (for Jira Cloud API token)

Datadog’s official Helm-based installation flow uses an existing Kubernetes Secret for the API key and a `datadog-values.yaml` file. citeturn3search12  
For local clusters such as kind/minikube, Datadog recommends setting kubelet TLS verification to `false` when needed. citeturn0search10turn0search1  
Datadog’s daemonset/agent supports APM trace collection by exposing port `8126` on the host. citeturn0search18

## Quickstart

1) Create your env file:

```bash
cp .env.example .env
```

2) Edit `.env` and set at least:

- `DATADOG_API_KEY`
- `DD_SITE` (e.g., `datadoghq.eu` or `datadoghq.com`)
- `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`
- (Optional) `JIRA_JQL`

3) Bring everything up (this uses a tooling container to avoid installing kind/kubectl/helm on your host):

```bash
make up
```

4) Check status:

```bash
make status
```

5) Follow app logs:

```bash
make logs
```

6) Tear down:

```bash
make down
```

## What to look for in Datadog

- **Kubernetes**
  - Cluster: `dd-jira-kind` (default; configurable via `KIND_CLUSTER_NAME`)
  - Node and pod metrics
- **APM**
  - Service: `jira-poller`
  - Spans around each polling cycle (requests to Jira)
- **Logs**
  - Container logs from `jira-poller` pods
  - Agent logs from the Datadog Agent pods (optional)

## Configuration

### Jira poller
Key environment variables (see `.env.example`):

- `JIRA_BASE_URL` – Jira base URL
- `JIRA_EMAIL` – Jira account email
- `JIRA_API_TOKEN` – Jira API token
- `JIRA_JQL` – JQL for the search query (default included)
- `POLL_INTERVAL_SECONDS` – default 30

### Datadog
Helm values are in `datadog/values.yaml`. Key features enabled:
- Logs collection for all containers
- APM (port 8126 enabled)
- DogStatsD hostPort enabled for custom metrics

## Notes / trade-offs

- This is a **single-node** kind cluster intended for local demos.
- The project deliberately uses **hostPort** for DogStatsD/APM so the app can reach the Agent via `status.hostIP`.
- Keep `.env` out of source control.

## Troubleshooting

- **No data in Datadog**
  - Verify `DATADOG_API_KEY` and `DD_SITE` in `.env`.
  - Check Agent pods: `make status` and `docker ps` (kind node container running).
- **Jira requests failing**
  - Confirm `JIRA_BASE_URL` includes `https://` and is correct.
  - Ensure the API token is valid and permissions allow the JQL query.
  - Inspect logs: `make logs`.

## License
MIT (see LICENSE).
