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
- Enable the GCP APIs needed for Vertex AI–based agent development; document the
  one manual step AWS requires (Bedrock model access) since it can't be automated
  via Terraform.
- Cap spend with tight, low-threshold budget alerts appropriate for a ~2-day
  build window.
- Provision both as plain, unmodified instantiations of the existing shared
  baseline modules — zero changes to shared module code, zero impact on other
  already-provisioned projects.

## Non-Goals

- **Teammate IAM access.** Originally planned as an extension to the shared
  baseline modules (see "Superseded" below), but this repo (`core-infra`) also
  manages unrelated personal domains, certs, and other personal projects —
  granting teammates access to *this* repo's Terraform/state would over-expose
  scope. Teammate access will instead be handled by a separate,
  hackathon-specific repo (not yet created) that teammates actually have access
  to. That repo's own IaC — created independently, possibly at or just before
  the event — is responsible for creating individual teammate identities
  against the `vista-hackathon-2026` project/account provisioned here. Out of
  scope for this spec.
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

### 2. Teammate IAM — superseded, out of scope

**Superseded.** The original design extended both shared baseline modules with
optional `teammate_emails` / `teammate_usernames` variables (empty-list default,
so existing projects would see no diff). This is no longer part of this spec —
see "Teammate IAM access" under Non-Goals. `vista-hackathon-2026` is provisioned
here as a plain baseline instantiation owned solely by `admin_user`
(GCP)/the account creator (AWS), identical in shape to every other personal
project in this repo. No baseline module changes are needed.

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

- `terraform validate` and `terraform fmt -recursive` on the two new
  project/account roots.
- `terraform plan` on every *other* existing GCP project and AWS account to
  confirm this change touches no shared module code and produces no diff
  anywhere else in the repo.
- `terraform plan` on `vista-hackathon-2026` (both providers) reviewed by hand
  before `terraform apply`, since this creates real billable resources.
- Manual: confirm budget alert email/PagerDuty subscription arrives after apply.

## Open Items (deferred, not blocking)

- The hackathon-specific repo (teammate IAM, app code) — to be created
  separately, not part of this spec.
- Bedrock model access request — manual console step, done once account ID is
  known (after `aws organizations create-account`).
