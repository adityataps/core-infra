# Budget-only PagerDuty coverage repairs

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver budget threshold notifications from all billable cloud accounts to PagerDuty, preserving existing recipients and budgets.

**Architecture:** GCP Billing Budgets uses a dedicated PagerDuty email integration. AWS account SNS topics use one management-account Lambda to translate budget notifications to Events API v2 and confirm cross-account SNS subscriptions. Only budget thresholds page; health alarms remain console-only.

**Tech stack:** Terraform >= 1.5; existing Google, AWS, and PagerDuty providers; archive provider; Python 3.12 standard library.

**Spec:** `docs/operations/pagerduty-coverage.md` and the user's explicit requirement that PagerDuty remain budget-only.

## Constraints and review focus

- Preserve all budget limits, filters, thresholds, existing administrator recipients, and application resources/cutoff actions.
- No synthetic notifications or test incidents; validate saved plans and live route configuration without printing keys.
- Leave the unbilled `liquid-optics-417722` project intact; its creator is not established.
- Keep application budget/topic ownership separate; core-infra adds only its own subscriber.
- SNS control messages must complete confirmation and must never become PagerDuty incidents.
- Workload and delivery-health signals must not page PagerDuty.

## Tasks

- [x] Add supported GCP budget email routing for four managed projects; import two unowned legacy budgets and preserve their settings while adding recipients.
- [x] Add an AWS budget Events API v2 integration, shared forwarder, scoped source-topic permissions, retries, encrypted failure queue, and six SNS subscriptions.
- [x] Test notification transformation, malformed batches, HTTP failures, retry deduplication, and SNS confirmations; 30 tests pass.
- [x] Remove five unsupported CloudWatch budget HTTPS subscriptions after verifying replacement routes.
- [x] Apply budget-only scope: remove the three deployed GCP workload policies and seven AWS workload alarms plus their routes; keep two forwarder health alarms console-only. Do not deploy the proposed Scheduler alert.
- [x] Verify budget-only live routing, format/validate, and update generated documentation.
- [x] Publish the final budget-only change (merged PR #189; Plan and Validate checks pass).

## Execution notes

- Legacy GCP imports needed a second plan after channel creation before recipient updates were detected; all six budgets then had two enabled email routes.
- Initial cross-account subscription setup exposed an unhandled SNS confirmation path and triggered incident #16. The incident is resolved, confirmation handling is deployed, the exact failed record was recovered, and regression tests cover it. No test incident was deliberately generated.
- All six AWS SNS Lambda subscriptions were confirmed; code, integration key, source permissions, retries, encryption, and empty failure queue were inspected live.
- The user subsequently clarified that PagerDuty must carry budget alerts only. This supersedes the earlier workload-monitoring design. Remove only resources added in this session; keep application services, jobs, permissions, and existing inactive vendor integrations/channels intact.
- Existing follow-ups: graph-gen-daily's latest execution returned permission-denied status code 7; Vista's full plan has unrelated OIDC thumbprint drift. Neither application/IAM setting is changed as part of budget routing.
- A speculative application-topic policy change was unnecessary and was never published or applied.

- Final budget-only verification: all six AWS routes confirmed, five administrator email subscriptions retained, zero PagerDuty HTTPS SNS routes across the five accounts in us-east-1; two management health alarms have disabled/empty actions. All five GCP projects have zero workload alert policies while all six budgets retain both email routes.

- Subsequent user-approved app repair: tapshalkar.com PR #47 grants invocation on graph-gen only and sets Sunday 06:00 UTC scheduling. The inspected plan had exactly one IAM create and one schedule update; both were applied and live-verified without invoking the job. PagerDuty remains budget-only.
