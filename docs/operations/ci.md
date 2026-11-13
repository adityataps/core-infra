# Terraform CI

## Check scope

`terraform-validate.yml` checks every Terraform root and reusable module without backend initialization. It needs no cloud credentials and runs for Dependabot and fork PRs.

`terraform-plan.yml` and `terraform-drift.yml` authenticate through the management GCP service account. They use the `ci-plan` Make target: GCP organization and four GCP projects. PagerDuty is consumed through existing remote state, but its root is not planned because CI has no PagerDuty API token. AWS roots need their own credentials and are not part of this authenticated scope.

Both planning workflows use `scripts/tf-all.sh` to normalize status: `0` means clean, `1` means error, and `2` means pending changes. Do not interpret Make exit codes as Terraform exit codes.

## State lock recovery

The management root declares `google_storage_bucket_iam_member.github_actions_state_locks` in `ci.tf`. This grants the CI service account object administration only on `.tflock` objects in the shared bucket; it does not grant writes to state files. Existing state-read permissions are still required.

Use an administrator identity to deploy this permission; the CI service account cannot bootstrap its own missing permissions:

```bash
gcloud auth login
gcloud auth application-default login
cd providers/gcp/projects/management/tapshalkar-com
terraform init -backend-config=backend.hcl
terraform plan -target=google_storage_bucket_iam_member.github_actions_state_locks -out=/tmp/ci-state-locks.tfplan
terraform show /tmp/ci-state-locks.tfplan
# Apply only if the reviewed plan contains the expected lock permission change.
terraform apply /tmp/ci-state-locks.tfplan
```

The targeted plan is a one-time recovery operation, not the normal deployment workflow. Follow it with a full plan to check for other pending changes. The first corrected CI run may reveal permissions or drift hidden by the old false-success handling.

## Restore the schedule

After deploying the workflow fixes and lock permission:

```bash
gh workflow enable terraform-drift.yml --repo adityataps/core-infra
gh workflow run terraform-drift.yml --repo adityataps/core-infra
gh run list --repo adityataps/core-infra --workflow terraform-drift.yml --limit 3
```

Inspect the resulting run. Exit `2` deliberately fails the drift check and opens or updates the drift issue; exit `1` means the check itself failed and must be investigated. Neither means it is safe to apply changes without reviewing a plan.

GitHub automatically disables scheduled workflows in inactive public repositories after 60 days. Reactivate this workflow after that happens; a schedule that stops running is not evidence that drift was resolved.
