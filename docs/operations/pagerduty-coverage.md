# PagerDuty coverage audit

Audit completed 2026-11-12 (America/New_York), after cloud authentication was refreshed. The monitoring inspection was read-only: no monitoring resources were changed and no test incidents or notifications were generated. CI IAM repairs are documented separately.

## Result

**AWS account budget coverage is configured and live-verified for all five accounts. GCP PagerDuty coverage is incomplete:** four managed projects have enabled channels but no alert policies, budgets route only to email, and one additional active project has no notification channels or alert policies.

## Live inventory

- AWS organization: five active accounts; all represented in this repository. Directory `personal/vista-hackathon-2026` manages the account named `tapshalkar-vista-hackathon-26`; this is a naming difference, not a missing account.
- GCP organization `tapshalkar.com`: five active projects. Four have repository roots. `liquid-optics-417722` (display name `My Project 66553`) has no repository root, no live notification channels, no live alert policies, and no project-filtered budget among the six budgets found on the configured billing account.

## AWS: configured and live-verified

All account resources below are deployed in the configured region, `us-east-1`.

| Account | Baseline monthly budget → SNS | PagerDuty HTTPS subscription | Integration key | Email subscription |
| --- | --- | --- | --- | --- |
| tapshalkar-com | Verified, 50/90/100% ACTUAL thresholds | Confirmed | Matches live AWS integration | Confirmed |
| tapshalkar-com-personal | Verified, 50/90/100% ACTUAL thresholds | Confirmed | Matches live AWS integration | Confirmed |
| tapshalkar-com-sandbox | Verified, 50/90/100% ACTUAL thresholds | Confirmed | Matches live AWS integration | Confirmed |
| tapshalkar-com-certs | Verified, 50/90/100% ACTUAL thresholds | Confirmed | Matches live AWS integration | Confirmed |
| tapshalkar-vista-hackathon-26 | Verified, 50/90/100% ACTUAL thresholds | Confirmed | Matches live AWS integration | Confirmed |

Every baseline monthly budget notification targets its account's `budget-alerts` topic, and every topic policy permits AWS Budgets to publish. The PagerDuty remote-state output matches the current live Amazon CloudWatch integration key. No subscription is pending.

**Additional gap:** Vista also has a `payinvestigator-bedrock-monthly` budget with 80% and 100% ACTUAL notifications targeting `payinvestigator-bedrock-budget-alerts`. That topic has **zero subscriptions**, so those budget notifications currently have no SNS delivery recipients. The account's separate baseline monthly budget remains connected to PagerDuty.

No AWS CloudWatch alarms are defined in this repository. Live CloudWatch inspection found zero alarms in `us-east-1` across all five accounts. Other regions were not scanned.

## GCP: configured versus live

| Project | Live PagerDuty channel | Live alert policies | Live budget notification route |
| --- | --- | --- | --- |
| tapshalkar-com | Enabled | 0 | Email only |
| tapshalkar-com-personal | Enabled | 0 | Email only |
| tapshalkar-com-sandbox | Enabled | 0 | Email only |
| tapshalkar-com-web | Enabled | 0 | Email only |
| liquid-optics-417722 | Absent | 0 | No project-filtered budget found |

All four managed project budgets have 50/90/100% thresholds, exactly one email channel, no Pub/Sub route, and default IAM recipients disabled. This matches the declared Terraform behavior. The billing API initially returned SERVICE_DISABLED for the default quota project; using the management project as quota project resolved the read, without changing any APIs or permissions.

GCP masks notification channel service keys in live API responses. For each managed project, the unmasked visible characters are consistent with the expected integration key, the live channel identity matches Terraform state, and the full key stored in that project's state matches the live PagerDuty GCP integration. Full equality of the masked live API value cannot be proven from that response alone. No key mismatch was observed.

The configured billing account also has two additional budgets: `tapshalkar-vista-hackathon-26-monthly-budget` and `vista-hackathon-2026-monthly-budget`. Their project references could not be resolved and are absent from the active organization inventory. Both budgets have no configured notification channels or Pub/Sub topic, and default IAM recipients are disabled. They currently have no configured notification delivery route.

The baseline deliberately leaves workload alert policies to project-specific configuration, but none exist in this repository or live in any of the five inventoried projects. A PagerDuty notification channel by itself does not produce alerts. Baseline/project outputs also do not export notification channel IDs, although `monitoring.tf` suggests remote-state access to them.

## PagerDuty: live verified

| Service | Status | Expected integration | Routing key present | Escalation policy attached |
| --- | --- | --- | --- | --- |
| AWS Monitoring | active | Amazon CloudWatch | Yes | Yes |
| GCP Monitoring | active | Google Cloud Monitoring | Yes | Yes |

Both PagerDuty Terraform remote-state outputs exactly match the corresponding current live integration keys. Keys, credentials, SNS endpoints, and Terraform state contents were not displayed or saved to audit artifacts. State was parsed in memory only.

## Other providers and limits

Hetzner, MongoDB Atlas, and Supabase roots are resource stubs without PagerDuty configuration. Cloudflare and GitHub roots manage DNS/repository settings rather than cloud account monitoring and contain no PagerDuty alert routing. Organization roots manage hierarchy rather than workload alert policies.

Cloud and PagerDuty authentication blocks from the initial pass were resolved. Configuration and subscription confirmation were verified without generating notifications; actual event ingestion and on-call delivery were not tested. No monitoring configuration was added or repaired.

## Evidence paths

- `providers/aws/modules/baseline/budgets.tf:32`: SNS PagerDuty subscription.
- `providers/aws/modules/baseline/budgets.tf:43`: per-account monthly budget.
- `providers/aws/accounts/management/tapshalkar-com/main.tf:26`: management key wiring; each member root also passes `aws_integration_key`.
- `providers/aws/accounts/personal/vista-hackathon-2026/main.tf:10`: actual Vista account name.
- `providers/gcp/modules/baseline/budgets.tf:13`: PagerDuty channel.
- `providers/gcp/modules/baseline/budgets.tf:47`: email-only budget routing.
- `providers/gcp/modules/baseline/monitoring.tf:1`: workload policies left to project configuration.
- `providers/gcp/modules/baseline/outputs.tf`: no notification channel output.
- `providers/pagerduty/main.tf:25`: GCP Monitoring service/integration.
- `providers/pagerduty/main.tf:48`: AWS Monitoring service/integration.
