# Vista Hackathon 2026 — Dual-Cloud Environment Design

## Context

Attending the 2026 Vista Hackathon (North America, July 13–15, Scottsdale AZ) — an
agentic AI orchestration challenge judged on a live demo built during the event
window. Teams are required to bring their own cloud environment; this repo's
personal cloud accounts (tapshalkar-com) will serve as the actual environment the
team (4–5 people, possibly plus an embedded HBCU student) uses during the event —
not just a personal prep sandbox.

Both AWS and GCP will be provisioned ahead of time so the team can pick whichever
fits the (currently unknown) challenge prompt once it's revealed at kickoff.
Provisioning cloud credentials, dev environments, and CI/CD is explicitly allowed
before the event per the hackathon rules; building application logic is not.

## Goals

- Stand up one new GCP project and one new AWS account, both named
  `vista-hackathon-2026`, under the existing `personal/` folder/OU.
- Give each teammate their own named IAM identity in both clouds (auditable,
  individually revocable after the event) rather than a shared credential.
- Enable the GCP APIs needed for Vertex AI–based agent development; document the
  one manual step AWS requires (Bedrock model access) since it can't be automated
  via Terraform.
- Cap spend with tight, low-threshold budget alerts appropriate for a ~2-day
  build window.
- Do all of this as a minimal, backward-compatible extension of the existing
  shared baseline modules — zero impact on other already-provisioned projects.

## Non-Goals

- No application-specific infrastructure (agent hosting, databases, etc.) —
  the challenge prompt isn't known until the event starts, and pre-building app
  logic is against the rules.
- No automated teardown/lifecycle tooling. Destruction after the event is a
  manual `terraform destroy`, run once, by hand.
- No changes to `create-gcp-project.sh` / `create-aws-account.sh` — both already
  produce a working baseline instantiation for a new project/account.

## Design

### 1. New accounts/projects

Scaffolded using the existing, unmodified scripts:

```bash
./scripts/create-gcp-project.sh personal vista-hackathon-2026
./scripts/create-aws-account.sh personal vista-hackathon-2026
```

This wires up remote state, GitHub Actions OIDC, budget resources, and
Makefile/`tf-all.sh` targets automatically, following the exact pattern used by
every other project/account in this repo.

### 2. Teammate IAM — baseline module extension

Today, `providers/gcp/modules/baseline` supports exactly one identity
(`admin_user`, bound as `roles/owner`), and `providers/aws/modules/baseline` has
no IAM user support at all — only the GitHub Actions OIDC role. Individual
teammate access requires extending both shared modules.

**GCP (`providers/gcp/modules/baseline`)**

- New variable `teammate_emails` (`list(string)`, default `[]`).
- New resource: `google_project_iam_member` with `for_each` over
  `toset(var.teammate_emails)`, binding each as `roles/editor` — project-scoped,
  not org-level.

**AWS (`providers/aws/modules/baseline`)**

- New variable `teammate_usernames` (`list(string)`, default `[]`).
- New resources per username (`for_each`):
  - `aws_iam_user`
  - `aws_iam_user_login_profile` (auto-generated password, `password_reset_required = true`)
  - `aws_iam_user_policy_attachment` → AWS managed `PowerUserAccess` policy
    (broad access for building; excludes IAM/org-level changes)

Both variables default to an empty list, so `terraform plan` for every other
existing project/account (`tapshalkar-com`, `-web`, `-sandbox`, `-personal`,
certs accounts) shows **no diff** — this is purely additive.

In `vista-hackathon-2026` itself, both lists start empty with a
`# TODO: fill in teammate emails/usernames before the event` comment in
`terraform.tfvars`, since the team roster isn't finalized yet. Filling them in
and re-applying is the only step needed once names are known.

### 3. AI/agentic service enablement

**GCP `enabled_apis`** — baseline set (`compute`, `iam`, `cloudbilling`,
`billingbudgets`, `cloudresourcemanager`, `logging`, `monitoring`,
`iamcredentials`) plus:

- `aiplatform.googleapis.com` — Vertex AI (Gemini models, Agent Builder, Model Garden)
- `discoveryengine.googleapis.com` — Vertex AI Agent Builder / grounding
- `run.googleapis.com` — Cloud Run, for hosting agent backends / MCP servers
- `artifactregistry.googleapis.com` — container images for Cloud Run
- `secretmanager.googleapis.com` — API keys / secrets
- `storage.googleapis.com` — Cloud Storage

**AWS** — Bedrock isn't gated by an "enable API" step in Terraform; access is
covered by the `PowerUserAccess` policy teammates already receive. The one thing
Terraform cannot do is request foundation-model access (e.g. Anthropic Claude on
Bedrock) — this is a one-time manual click per account/region in the Bedrock
console ("Model access" page). This will be called out explicitly in the
generated next-steps output as a pre-event manual step.

### 4. Budget & lifecycle

- Both accounts: `budget_amount = 100`, `budget_thresholds = [0.5, 0.9, 1.0]`.
- Alerts route through the existing email + PagerDuty integration, already wired
  by the scaffolding scripts (no new wiring needed).
- No auto-teardown automation. After the event, both roots are destroyed
  manually via `terraform destroy` when ready — building throwaway lifecycle
  tooling for a one-off 2-day event isn't worth the complexity.

## Testing / Verification

- `terraform validate` and `terraform fmt -recursive` on both new module
  extensions and the two new project/account roots.
- `terraform plan` on every *existing* GCP project and AWS account to confirm
  the new `teammate_emails` / `teammate_usernames` variables produce **zero
  diff** (empty-list default proves backward compatibility).
- `terraform plan` on `vista-hackathon-2026` (both providers) reviewed by hand
  before `terraform apply`, since this creates real billable resources.
- Manual: confirm budget alert email/PagerDuty subscription arrives after apply.

## Open Items (deferred, not blocking)

- Actual teammate emails/usernames — filled in once the roster is finalized,
  before or at the event.
- Bedrock model access request — manual console step, done once account ID is
  known (after `aws organizations create-account`).
