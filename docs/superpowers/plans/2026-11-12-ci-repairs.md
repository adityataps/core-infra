# CI repairs and PagerDuty audit

**Goal:** Make CI failures trustworthy, validate Dependabot changes without cloud credentials, restore authenticated drift checks, and establish PagerDuty coverage.

**Approach:** Keep existing Terraform roots and remote state paths. Use the existing `tf-all.sh` wrapper to normalize Terraform and Make exit codes. Restrict CI lock permissions to lock objects in the existing state bucket. Keep credential-free validation separate from authenticated planning.

## Tasks

- [x] Add failing regression tests for plan errors, init errors, drift, invalid targets, and invocation outside the repository.
- [x] Repair script error aggregation and workflow exit handling; read plan logs from files when posting results.
- [x] Add credential-free Terraform validation for all roots; skip authenticated plans for Dependabot and fork PRs. Remove PagerDuty from GCP-only planning because its provider requires separate credentials.
- [x] Declare state-lock IAM permissions in the management root and validate Terraform. Applied the saved plan after verifying it contained exactly one IAM addition and no other changes.
- [x] Audit Terraform and live PagerDuty resources. Document budget versus workload coverage and cloud resources blocked by expired authentication.
- [ ] Review changes, run regression tests and workflow/config checks, restore the drift schedule, and verify a run when the fixes are deployed.

## Verification

Run the real shell scripts with a fake Terraform executable so tests exercise Make, exit statuses, cleanup, and progress reporting without modifying cloud infrastructure. Run shell syntax checks, Terraform formatting and validation, and workflow linting. Inspect live resources without sending incidents or exposing integration keys.

## Constraints and review focus

- A failed init or plan must never become a successful check, even if other modules have drift.
- Terraform exit `2` means drift; Make exit `2` means error and must be normalized.
- Validation for Dependabot and forks must require no cloud credentials or remote state access.
- Keep Terraform state locking enabled and avoid granting state-object write access to CI.
- Do not infer live alert delivery from the presence of notification-channel configuration.
- Cloud login refresh is required for live AWS/GCP verification and the IAM deployment.

## Progress

- Baseline: working tree clean; Terraform formatting passes. Work is on `fix/github-actions`.
- GCP user credentials and ADC require reauthentication; AWS SSO sessions are expired. User has been asked to refresh both while local work continues.
- Local checks: 12 regression tests pass (seven initially reproduced current failures, plus a standalone apply exit-status regression). All 21 Terraform roots/modules validate. Terraform formatting, shell syntax, actionlint, and documentation links pass.
- State-lock IAM declaration validates; deployment and an authenticated workflow run remain pending GCP login refresh. Live AWS/GCP alert verification remains pending refreshed credentials.
- Authentication refreshed. State-lock IAM deployed: one resource added, none changed or destroyed. The subsequent full management plan reports no changes. Live audit follow-up and hosted CI checks are in progress.
- Independent review: no critical or important code findings. Corrected audit wording to distinguish backend-free provider initialization from live resource inspection. Deferred additional test coverage for drift-workflow shell, GitHub event guards, backend-free initialization, and independent Make prerequisites; local behavior checks and workflow linting pass, but an observed hosted run remains required.
- Hosted PR checks caught previously hidden missing organization permissions and missing Linux platform checksums in read-only initialization. Adding scoped read grants for the full CI hierarchy and verified Linux/macOS provider hashes without upgrading providers. The cloud audit is complete; see `docs/operations/pagerduty-coverage.md` for live gaps.
- Review ruling: GCP does not document organization resource-attribute conditions for IAM policy reads. Removed the proposed condition before applying it; use predefined read-only Organization Security Reviewer instead. Tradeoff: CI can review IAM metadata throughout the organization, rather than only the root policy. No new resource write rights are granted.
- Hosted follow-up: organization and management plans now report no changes. The first personal project's pool refresh still denies `iam.workloadIdentityPools.get` with basic Viewer; adding explicit Workload Identity Pool Viewer on the same three projects, based on the observed API denial rather than role-metadata name assumptions.
