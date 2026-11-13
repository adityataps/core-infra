# PagerDuty budget coverage

Updated 2026-11-12 (America/New_York).

## Paging policy

**PagerDuty is reserved for budget threshold notifications across all cloud accounts.** Workload failures, scheduler failures, and budget-forwarder health do not page PagerDuty. The workload policies and routes added during the initial repair were removed when the user clarified this policy. The proposed Scheduler policy was never deployed.

All five AWS account budgets and all six GCP budgets have supported PagerDuty routes. Existing administrator email recipients, budget amounts, project/service filters, thresholds, and Vista's automatic Bedrock cutoff action were preserved.

Configuration and SNS confirmation handshakes were inspected live. No synthetic budget events, workload failures, or intentional test incidents were sent. Actual budget event ingestion and on-call delivery remain untested. A setup failure caused incident #16, described below; it is resolved.

## AWS

Budget delivery is:

`AWS Budgets → existing account SNS topic → central Lambda → PagerDuty Events API v2`

The shared `budget-pagerduty-forwarder` runs in the management account in `us-east-1`. Its invocation policy permits exactly the six current budget topic ARNs. A dedicated Events API v2 integration routes to the existing AWS PagerDuty service and escalation policy.

| Account | Budget topic | Supported subscription |
| --- | --- | --- |
| tapshalkar-com | budget-alerts | Confirmed Lambda |
| tapshalkar-com-personal | budget-alerts | Confirmed Lambda |
| tapshalkar-com-sandbox | budget-alerts | Confirmed Lambda |
| tapshalkar-com-certs | budget-alerts | Confirmed Lambda |
| tapshalkar-vista-hackathon-26 | budget-alerts | Confirmed Lambda |
| tapshalkar-vista-hackathon-26 | payinvestigator-bedrock-budget-alerts | Confirmed Lambda |

Baseline budgets retain 50/90/100% ACTUAL thresholds; the additional Bedrock budget retains 80/100%. All five baseline administrator email subscriptions remain confirmed. The Bedrock budget and topic belong to the application configuration; core-infra owns only its new subscription, without importing or modifying its budget, topic, or cutoff action.

The five old budget HTTPS subscriptions were removed: PagerDuty's CloudWatch integration expects a CloudWatch payload and does not establish support for raw AWS Budgets messages. New direct budget email recipients are unsuitable for unattended setup because AWS requires per-account recipient verification.

The forwarder validates SNS envelopes, preserves notification text, and deduplicates retries using topic ARN plus SNS message ID. It requires HTTP 202 and a success response from PagerDuty. Delivery failures raise sanitized errors, receive two Lambda retries, and go to an encrypted failure queue with 14-day retention. Its execution role permits only writes to its own log group and failure queue. Routing keys are explicitly marked sensitive and are never logged by the handler.

Cross-account SNS subscriptions created by the topic owner deliver `SubscriptionConfirmation` control messages to Lambda. The handler confirms these through the regional AWS SNS API using their token, constructs the endpoint from the validated topic ARN, ignores the supplied URL, and never forwards control messages to PagerDuty. During initial setup this path was missing and triggered **incident #16**. It was repaired with regression tests; the exact failed subscription was confirmed and its setup-only failure record removed. The incident is resolved.

Two budget-delivery health alarms remain **console-only**: Lambda Errors and queued undelivered notifications. Their actions are disabled and their ALARM/OK destination lists are empty. No CloudWatch workload alarm or health topic is connected to PagerDuty. The seven Vista workload alarms, ingestion metric filter, and workload notification resources added during this session were removed; application resources were left intact.

## GCP

Budget delivery is:

`Cloud Billing Budget → Monitoring email channel → dedicated PagerDuty email integration`

Billing Budgets accepts email notification channels or Pub/Sub, not a PagerDuty Monitoring channel. The dedicated email integration uses a randomly suffixed address supplied through ignored sensitive tfvars. Every budget retains an administrator email channel alongside the new PagerDuty email channel. All six live budgets were checked for two enabled email recipients, an exact integration-address match, and unchanged thresholds.

| Project/budget scope | Budget delivery |
| --- | --- |
| tapshalkar-com | Administrator + PagerDuty email |
| tapshalkar-com-personal | Administrator + PagerDuty email |
| tapshalkar-com-sandbox | Administrator + PagerDuty email |
| tapshalkar-com-web | Administrator + PagerDuty email |
| tapshalkar-vista-hackathon-26 legacy budget | Administrator + PagerDuty email |
| vista-hackathon-2026 legacy budget | Administrator + PagerDuty email |

The two older USD 100 budgets were imported into the management root after confirming their former remote states contained no managed resources. Their original project numbers could not be resolved. Filters, amounts, and thresholds were preserved. Import/channel creation required a follow-up plan before their recipient updates were detected.

Email incidents group by matching subject while open. A different threshold subject or a later email after resolution can open another incident; budget emails have no reliable recovery event. Email channel verification status is unspecified, which the API allows when verification is not required, rather than UNVERIFIED. Budget email delivery can be delayed and has not been tested end to end.

The three Cloud Run alert policies added during the initial repair were removed. The proposed `graph-gen-daily` log-based alert was never applied. Existing unused Monitoring vendor integrations/channels were left intact; no workload policies route through them.

## Scheduler investigation

The existing `graph-gen-daily` Scheduler job in `tapshalkar-com-web/us-east1` calls the Cloud Run job `graph-gen` using OAuth as `graph-gen-sa@tapshalkar-com-web.iam.gserviceaccount.com`. November 5–12 execution logs show HTTP 403 / PERMISSION_DENIED. The caller has storage access but no Run invocation grant on the job, project, folder, or organization; `roles/run.invoker` on that job would provide the missing `run.jobs.run` permission. Scheduler service-agent configuration is present and the job is Ready.

Graph generation fetches personal activity/profile data, uses Claude, and writes the site's graph/activity JSON files to GCS. Daily 06:00 UTC matches an explicit local Terraform override; README/defaults describe weekly execution, so this is not unexplained schedule drift. The user is discussing whether generation should resume daily, resume weekly, or be disabled. The job and its permissions remain unchanged, and no Scheduler failure routes to PagerDuty.

## What is liquid-optics-417722?

This older GCP project belongs to the `tapshalkar.com` organization:

- Created **2024-03-19 at 22:01:51 UTC**.
- Display name **My Project 66553**; project number **871904253162**.
- Sole direct project IAM owner: **aditya@tapshalkar.com**.
- Billing is disabled and no billing account is linked.
- No service accounts, storage buckets, or BigQuery datasets were found. Compute Engine, Cloud Run, and Gemini API services are not enabled.
- No retained project creation logs were found, so the creator/application cannot be established. Its default-looking name and generated ID suggest console creation but do not prove it.

It appears dormant and unbilled. It was left intact, without enabling billing, importing it, adding resources, or deleting anything. No billable workload was established. Cloud Asset and API Keys inventory APIs were unavailable through the management quota project; they were not enabled solely for this investigation. This is an investigated exception, not evidence that the project should be deleted.

## Verification and operations

- Thirty tests cover the forwarder's Events API contract, retry deduplication, bounded payloads, malformed batches, HTTP/network failures, and SNS control confirmations, plus existing CI script regressions.
- Saved Terraform plans were inspected before applies. Live checks compared integration keys only in memory and reported safe counts/booleans.
- The earlier CI repair is [PR #188](https://github.com/adityataps/core-infra/pull/188).
- Vista's full Terraform plan has an existing unrelated GitHub OIDC thumbprint difference. Monitoring removal excluded that update; it was not overwritten.
- To add another AWS account, ensure its account exists before applying management so the organization-derived Lambda source-topic allowlist includes it, then apply its baseline. All current SNS/Lambda subscriptions use `us-east-1`; a different region needs a compatible regional setup.
- Inspect delivery problems in the forwarder's CloudWatch logs, console-only alarms, and failure queue without printing payloads or routing keys. SNS confirmation records must be confirmed as control messages, not redriven as budget incidents. Review actual budget records before retrying delivery.
- Hetzner, MongoDB Atlas, and Supabase roots remain resource stubs. Cloudflare/GitHub roots manage DNS/repository configuration rather than application paging.

References: [Google budget recipients](https://cloud.google.com/billing/docs/how-to/budgets-notification-recipients), [PagerDuty CloudWatch contract](https://docs.pagerduty.com/integrations/amazon-cloudwatch-integration-guide), [AWS budget email verification](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-email-recipients.html), [SNS ConfirmSubscription](https://docs.aws.amazon.com/sns/latest/api/API_ConfirmSubscription.html).
