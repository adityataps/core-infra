# PagerDuty coverage audit

Audit date: 2026-11-12. Read-only inspection; no cloud mutations, test incidents, or test messages.

## Result

All five AWS account roots configure budget alerts to PagerDuty. All four GCP projects configure a PagerDuty notification channel, but GCP budgets route only to email, and this repository defines no GCP workload alert policies or AWS CloudWatch alarms. A configured channel alone does not provide operational alert coverage.

## Coverage configured in Terraform

| Provider | Account/project root | Budget routing to PagerDuty | Workload alerts in this repository |
| --- | --- | --- | --- |
| AWS | management/tapshalkar-com | Yes: monthly budget → SNS → PagerDuty HTTPS integration | No CloudWatch alarms defined |
| AWS | personal/tapshalkar-com-personal | Yes: monthly budget → SNS → PagerDuty HTTPS integration | No CloudWatch alarms defined |
| AWS | personal/tapshalkar-com-sandbox | Yes: monthly budget → SNS → PagerDuty HTTPS integration | No CloudWatch alarms defined |
| AWS | certs/tapshalkar-com-certs | Yes: monthly budget → SNS → PagerDuty HTTPS integration | No CloudWatch alarms defined |
| AWS | personal/vista-hackathon-2026 | Yes: monthly budget → SNS → PagerDuty HTTPS integration | No CloudWatch alarms defined |
| GCP | management/tapshalkar-com | No: email only | PagerDuty channel configured; no alert policies defined |
| GCP | personal/tapshalkar-com-personal | No: email only | PagerDuty channel configured; no alert policies defined |
| GCP | personal/tapshalkar-com-sandbox | No: email only | PagerDuty channel configured; no alert policies defined |
| GCP | personal/tapshalkar-com-web | No: email only | PagerDuty channel configured; no alert policies defined |

AWS baseline uses ACTUAL spend alerts at fractional thresholds (default 50%, 90%, 100%), publishes to the local budget-alerts topic, and configures a conditional HTTPS subscription using the shared Amazon CloudWatch integration key. Every AWS account root passes that key. The subscription resource requests automatic confirmation; live confirmation is unverified.

GCP baseline creates email and PagerDuty channels. The billing budget explicitly attaches only the email channel and disables default IAM recipients. There is no Pub/Sub-to-PagerDuty bridge in this repository. `monitoring.tf` deliberately leaves workload alert policies to project-specific configuration, but none are present here. It suggests remote-state access to notification channels, while neither baseline outputs nor project outputs export a channel ID.

## Live verified

PagerDuty API reads succeeded:

| Service | Status | Expected integration present | Escalation policy attached |
| --- | --- | --- | --- |
| AWS Monitoring | active | Amazon CloudWatch (one integration) | Yes |
| GCP Monitoring | active | Google Cloud Monitoring (one integration) | Yes |

Both integrations also have nonempty routing keys (values were not displayed). The AWS integration type is `event_transformer_api_inbound_integration`; GCP is `generic_events_api_inbound_integration`.

These checks establish that the PagerDuty service side exists. They do not prove cloud-to-PagerDuty delivery or on-call notification delivery.

## Live verification blocked

- AWS CLI: all configured profiles could not authenticate. SSO profiles reported expired/invalid SSO tokens; the default profile returned INVALID_REQUEST. Therefore AWS organization inventory, deployed budgets, SNS subscriptions/confirmation, integration-key matching, and any out-of-repository alarms could not be checked.
- GCP CLI user credentials and application-default credentials both require reauthentication. Therefore deployed project inventory, budgets, notification channel state, integration-key matching, out-of-repository alert policies, and remote Terraform state could not be checked.
- No backend initialization, remote-state download, apply, or delivery test was performed during the live audit. Separate static validation initialized the pinned PagerDuty provider with the backend disabled.

## Other providers

Hetzner, MongoDB Atlas, and Supabase roots are resource stubs and contain no PagerDuty setup. Cloudflare and GitHub roots manage DNS/repository settings rather than cloud account monitoring and contain no alert routing to PagerDuty. AWS organization and GCP organization roots define organization structure rather than workload alert policies. This assessment covers the repository's declared account/project roots; inaccessible live organization inventories may contain additional accounts or projects.

## Evidence paths

- `providers/aws/modules/baseline/budgets.tf:32`: SNS PagerDuty subscription.
- `providers/aws/modules/baseline/budgets.tf:43`: per-account monthly budget.
- `providers/aws/accounts/management/tapshalkar-com/main.tf:26`: management key wiring; each member account root similarly passes `aws_integration_key` to baseline.
- `providers/gcp/modules/baseline/budgets.tf:13`: PagerDuty channel.
- `providers/gcp/modules/baseline/budgets.tf:47`: email-only budget routing.
- `providers/gcp/modules/baseline/monitoring.tf:1`: no baseline workload policies.
- `providers/gcp/modules/baseline/outputs.tf`: no notification channel output.
- `providers/pagerduty/main.tf:25`: GCP Monitoring service/integration.
- `providers/pagerduty/main.tf:48`: AWS Monitoring service/integration.
