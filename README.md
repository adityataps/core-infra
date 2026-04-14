# core-infra

Terraform monorepo managing personal cloud infrastructure across GCP, AWS, and others.

## Structure

- `bootstrap/` — Creates the GCS remote state bucket. Run once manually before anything else.
- `providers/gcp/modules/baseline/` — Reusable module: GCP project defaults (APIs, IAM, budgets, labels, logging, Workload Identity).
- `providers/gcp/projects/<name>/` — Per-project instantiation of the baseline module.
- `providers/aws/` — AWS infrastructure (future).
- `scripts/` — Helper scripts.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) — authenticated via `gcloud auth application-default login`
- [pre-commit](https://pre-commit.com/#install) — `pip install pre-commit && pre-commit install`
- [terraform-docs](https://terraform-docs.io/user-guide/installation/)

## First-time setup

1. `cd bootstrap && cp terraform.tfvars.example terraform.tfvars` — fill in values
2. `cd bootstrap && terraform init && terraform apply`
3. `cd providers/gcp/projects/my-project && cp terraform.tfvars.example terraform.tfvars` — fill in values
4. `terraform init && terraform plan`
5. Import existing resources (see CLAUDE.md)
