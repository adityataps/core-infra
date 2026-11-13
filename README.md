# core-infra

Terraform monorepo managing personal cloud infrastructure across GCP, AWS, and others.

## Structure

- `bootstrap/` — Creates the GCS remote state bucket. Run once manually before anything else.
- `providers/gcp/modules/baseline/` — Reusable module: GCP project defaults (APIs, IAM, budgets, labels, logging, Workload Identity).
- `providers/gcp/projects/<folder>/<name>/` — Per-project instantiation of the baseline module.
- `providers/aws/` — Organization structure, account roots, and reusable account baseline.
- `scripts/` — Helper scripts.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) — authenticated via `gcloud auth application-default login`
- [pre-commit](https://pre-commit.com/#install) — `pip install pre-commit && pre-commit install`
- [terraform-docs](https://terraform-docs.io/user-guide/installation/)

## First-time setup

1. `cd bootstrap && cp terraform.tfvars.example terraform.tfvars` — fill in values
2. `cd bootstrap && terraform init && terraform plan && terraform apply`
3. `cd providers/gcp/projects/my-project && cp terraform.tfvars.example terraform.tfvars` — fill in values
4. `terraform init && terraform plan`
5. Import existing resources (see CLAUDE.md)

## CI and monitoring

- **Terraform Validate** checks formatting, shell regression tests, and every Terraform configuration without cloud credentials, including Dependabot and fork PRs.
- **Terraform Plan** plans the GCP roots for trusted changes. `scripts/tf-all.sh plan ci-plan` returns `0` for no changes, `1` for an error, and `2` for pending changes.
- **Terraform Drift Detection** uses the same GCP scope on a daily schedule. See the [CI recovery runbook](docs/operations/ci.md) for deployment and reactivation steps.
- [PagerDuty coverage audit](docs/operations/pagerduty-coverage.md) distinguishes configured budget routing, workload alerts, and live verification.

Run the shell regression tests locally with `python3 -m unittest discover -s tests -v`.
