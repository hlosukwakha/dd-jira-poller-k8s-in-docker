import os
import time
import json
import logging
from typing import Any, Dict, Optional

import requests
from ddtrace import patch_all, tracer
from datadog.dogstatsd import DogStatsd
from pythonjsonlogger import jsonlogger

patch_all(requests=True, logging=True)

LOG = logging.getLogger("jira_poller")
handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
LOG.addHandler(handler)
LOG.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())


def env(name: str, default: Optional[str] = None, required: bool = False) -> str:
    v = os.getenv(name, default)
    if required and (v is None or v.strip() == ""):
        raise SystemExit(f"Missing required env var: {name}")
    return v


def jira_headers(email: str, api_token: str) -> Dict[str, str]:
    # Jira Cloud uses Basic auth with email:token base64. requests can handle it via auth=(email, token),
    # but we include explicit headers to keep the request consistent across Jira Server/Cloud variations.
    return {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def search_issues(
    session: requests.Session,
    base_url: str,
    email: str,
    api_token: str,
    jql: str,
    max_results: int = 5,
) -> Dict[str, Any]:
    # NOTE: /rest/api/3/search is removed in Jira Cloud; use /rest/api/3/search/jql
    url = f"{base_url.rstrip('/')}/rest/api/3/search/jql"
    payload = {
        "jql": jql,
        "maxResults": max_results,
        "fields": ["key", "summary", "updated"],
    }
    r = session.post(
        url,
        headers=jira_headers(email, api_token),
        auth=(email, api_token),
        json=payload,
        timeout=20,
    )
    r.raise_for_status()
    return r.json()



def main() -> None:
    base_url = env("JIRA_BASE_URL", required=True)
    email = env("JIRA_EMAIL", required=True)
    api_token = env("JIRA_API_TOKEN", required=True)
    jql = env("JIRA_JQL", "assignee = currentUser() ORDER BY updated DESC")
    poll_interval = int(env("POLL_INTERVAL_SECONDS", "30"))

    dd_agent_host = env("DD_AGENT_HOST", "127.0.0.1")
    dd_dogstatsd_port = int(env("DD_DOGSTATSD_PORT", "8125"))
    statsd = DogStatsd(host=dd_agent_host, port=dd_dogstatsd_port)

    service = env("DD_SERVICE", "jira-poller")
    environment = env("DD_ENV", "dev")
    version = env("DD_VERSION", "0.1.0")

    LOG.info(
        "starting",
        extra={
            "jira_base_url": base_url,
            "poll_interval_seconds": poll_interval,
            "dd_agent_host": dd_agent_host,
            "dd_dogstatsd_port": dd_dogstatsd_port,
            "dd.service": service,
            "dd.env": environment,
            "dd.version": version,
        },
    )

    session = requests.Session()

    while True:
        start = time.time()
        with tracer.trace("jira.poll", service=service, resource="jira_search") as span:
            span.set_tag("jira.base_url", base_url)
            span.set_tag("jira.jql", jql)

            ok = False
            issue_count = 0
            error_type = None

            try:
                data = search_issues(session, base_url, email, api_token, jql)
                issue_count = int(data.get("total", 0))
                ok = True

                issues = data.get("issues", [])[:3]
                LOG.info(
                    "jira_search_ok",
                    extra={
                        "issue_count": issue_count,
                        "sample_keys": [i.get("key") for i in issues],
                    },
                )
            except Exception as e:
                error_type = type(e).__name__
                LOG.error(
                    "jira_search_error",
                    extra={
                        "error_type": error_type,
                        "error": str(e),
                    },
                )
                span.set_tag("error", True)
                span.set_tag("error.type", error_type)
                span.set_tag("error.msg", str(e))

            elapsed_ms = (time.time() - start) * 1000.0

            # Custom metrics
            tags = [f"service:{service}", f"env:{environment}", f"version:{version}"]
            statsd.gauge("jira.poll.issue_count", issue_count, tags=tags)
            statsd.histogram("jira.poll.latency_ms", elapsed_ms, tags=tags)
            statsd.increment("jira.poll.success" if ok else "jira.poll.failure", tags=tags + ([f"error_type:{error_type}"] if error_type else []))

        # Enforce poll interval
        sleep_s = max(0.0, poll_interval - (time.time() - start))
        time.sleep(sleep_s)


if __name__ == "__main__":
    main()
