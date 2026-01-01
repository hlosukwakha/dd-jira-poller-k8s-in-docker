SHELL := /bin/bash
CTL := docker compose run --rm ctl

.PHONY: up down status logs shell

up:
	$(CTL) ./scripts/bootstrap.sh

down:
	$(CTL) ./scripts/teardown.sh

status:
	$(CTL) ./scripts/status.sh

logs:
	$(CTL) ./scripts/logs-app.sh

shell:
	$(CTL) bash
