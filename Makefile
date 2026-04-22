# Terraform dependency graph
#
# Local usage (all modules, credentials from .tfvars):
#   make [all]                       # plan all (default)
#   make all CMD=apply               # apply all, prompt per module
#   make all CMD=apply AUTO_APPROVE=1  # apply all without prompting
#
# Or use the wrapper:
#   scripts/tf-all.sh plan
#   scripts/tf-all.sh apply [--auto-approve]
#
# CI usage (GCP WIF auth only):
#   make ci-plan
#
# Run a single target (and its prerequisites):
#   make gcp-management CMD=plan

CMD          ?= plan
AUTO_APPROVE ?= 0

RUN := scripts/tf-module.sh $(CMD) $(AUTO_APPROVE)

.PHONY: all \
        github-init pagerduty gcp-org aws-org hetzner mongodb supabase \
        gcp-management aws-management \
        gcp-personal-tapshalkar-com gcp-personal-sandbox \
        aws-personal-tapshalkar-com aws-personal-sandbox aws-certs \
        github-sync \
        ci-plan

# ── Entry point ───────────────────────────────────────────────────────────────
# hetzner, mongodb, supabase are excluded until they contain real resources.
# Run them individually: make hetzner | make mongodb | make supabase
all: github-sync

# ── Tier 4: github (2nd pass — writes AWS role ARNs as GH Actions secrets) ───
github-sync: gcp-management aws-management \
             gcp-personal-tapshalkar-com gcp-personal-sandbox \
             aws-personal-tapshalkar-com aws-personal-sandbox aws-certs
	@$(RUN) providers/github

# ── Tier 3: depend on management accounts ─────────────────────────────────────
gcp-personal-tapshalkar-com: pagerduty gcp-org github-init gcp-management
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-personal

gcp-personal-sandbox: pagerduty gcp-org github-init gcp-management
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-sandbox

aws-personal-tapshalkar-com: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/personal/tapshalkar-com-personal

aws-personal-sandbox: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/personal/tapshalkar-com-sandbox

aws-certs: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/certs/tapshalkar-com-certs

# ── Tier 2: depend on github + pagerduty + org layers ─────────────────────────
gcp-management: pagerduty gcp-org github-init
	@$(RUN) providers/gcp/projects/management/tapshalkar-com

aws-management: pagerduty github-init
	@$(RUN) providers/aws/accounts/management/tapshalkar-com

# ── Tier 1: no cross-module dependencies ──────────────────────────────────────
github-init:
	@$(RUN) providers/github

pagerduty:
	@$(RUN) providers/pagerduty

gcp-org:
	@$(RUN) providers/gcp/org

aws-org:
	@$(RUN) providers/aws/org

hetzner:
	@$(RUN) providers/hetzner

mongodb:
	@$(RUN) providers/mongodb

supabase:
	@$(RUN) providers/supabase

# ── CI: GCP WIF auth only (no AWS/GitHub/third-party credentials needed) ──────
# Remote state for all these modules already exists in GCS, so inter-module
# deps are not needed for plan — the state is read from GCS via WIF auth.
ci-plan:
	@$(RUN) providers/pagerduty
	@$(RUN) providers/gcp/org
	@$(RUN) providers/gcp/projects/management/tapshalkar-com
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-personal
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-sandbox
