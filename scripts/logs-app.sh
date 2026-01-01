#!/usr/bin/env bash
set -euo pipefail

source /workspace/scripts/lib.sh
ensure_kind_access


kubectl -n jira-poller logs deploy/jira-poller -f --tail=100
