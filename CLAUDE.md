# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform repository for managing core cloud infrastructure resources. It is currently in early initialization — Terraform modules and configurations are expected to be added under `scripts/` or at the root.

## Common Commands

```bash
# Initialize Terraform (required before plan/apply)
terraform init

# Preview infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Destroy infrastructure (destructive — confirm with user first)
terraform destroy
```

## Key Conventions

- `.tfvars` and `.tfvars.json` files are gitignored — they contain environment-specific secrets and should never be committed.
- `override.tf` / `*_override.tf` files are also gitignored — they are used for local overrides only.
- State files (`*.tfstate`, `*.tfstate.*`) are excluded from version control; remote state backends (e.g., S3, GCS, Terraform Cloud) should be configured for shared use.

## Structure

- `scripts/` — intended for shell or automation scripts supporting infrastructure workflows (currently empty).

## Pre-commit Hooks

Install once after cloning:
```bash
pip install pre-commit terraform-docs
pre-commit install
```

Hooks run automatically on `git commit`: `terraform fmt`, `terraform validate`, `terraform-docs` (regenerates README.md in each module/project dir).

## Importing Existing GCP Resources

When applying the GCP baseline against an existing project for the first time, import the project resource:

```bash
cd providers/gcp/projects/my-project
terraform import module.baseline.google_project.this projects/<PROJECT_ID>
```

If the billing account is already linked and IAM bindings exist, import them too — check `terraform plan` output and run `terraform import` for any resource showing unexpected diffs.

## Adding a New GCP Project

1. `cp -r providers/gcp/projects/my-project providers/gcp/projects/<new-name>`
2. Update `backend.tf` prefix to `gcp/<new-name>`
3. Fill in a new `terraform.tfvars`
4. `terraform init && terraform import module.baseline.google_project.this projects/<NEW_PROJECT_ID>`
5. `terraform plan && terraform apply`