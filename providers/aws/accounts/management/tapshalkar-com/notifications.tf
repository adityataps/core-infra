# PagerDuty budget alerts are wired via the baseline module (aws_sns_topic_subscription.pagerduty).
# The baseline module uses the Amazon CloudWatch service integration endpoint
# (https://events.pagerduty.com/integration/<key>/enqueue), which handles SNS
# SubscriptionConfirmation automatically — no manual confirmation step required.
