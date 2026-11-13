"""Translate AWS Budgets SNS notifications into PagerDuty Events API v2 events."""

from datetime import datetime
import hashlib
import json
import os
import re
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


def _topic_parts(topic_arn):
    if not isinstance(topic_arn, str) or not re.fullmatch(
        r"arn:aws(?:-[a-z-]+)?:sns:[a-z0-9-]+:\d{12}:[A-Za-z0-9_-]+(?:\.fifo)?",
        topic_arn,
    ):
        raise ValueError("Invalid SNS topic ARN")
    return topic_arn.split(":")


def _validate_token(token):
    if not isinstance(token, str) or not token.strip():
        raise ValueError("Invalid SNS confirmation token")


def confirm_subscription(topic_arn, token):
    """Confirm SNS control traffic using its token, never its supplied URL."""
    parts = _topic_parts(topic_arn)
    _validate_token(token)
    domain = "amazonaws.com.cn" if parts[1] == "aws-cn" else "amazonaws.com"
    request = urllib.request.Request(
        f"https://sns.{parts[3]}.{domain}/",
        data=urllib.parse.urlencode(
            {
                "Action": "ConfirmSubscription",
                "Version": "2010-03-31",
                "TopicArn": topic_arn,
                "Token": token,
            }
        ).encode("utf-8"),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status != 200:
                raise RuntimeError
            root = ET.fromstring(response.read(65_536))
            arn = next(
                (node.text for node in root.iter() if node.tag.rsplit("}", 1)[-1] == "SubscriptionArn"),
                None,
            )
            if not arn or not arn.startswith(topic_arn + ":") or len(arn) <= len(topic_arn) + 1:
                raise RuntimeError
            return arn
    except Exception:
        raise RuntimeError("SNS did not confirm the budget subscription") from None


def _notifications(event):
    """Validate the entire batch before performing an external side effect."""
    if not isinstance(event, dict):
        raise ValueError("Invalid SNS notification envelope")
    records = event.get("Records")
    if not isinstance(records, list) or not records:
        raise ValueError("Invalid SNS notification envelope")
    notifications = []
    for record in records:
        if not isinstance(record, dict) or record.get("EventSource") != "aws:sns":
            raise ValueError("Invalid SNS notification envelope")
        sns = record.get("Sns")
        if not isinstance(sns, dict) or sns.get("Type") not in {
            "Notification", "SubscriptionConfirmation"
        }:
            raise ValueError("Invalid SNS notification envelope")
        for field in ("TopicArn", "MessageId", "Timestamp", "Message"):
            if not isinstance(sns.get(field), str) or not sns[field].strip():
                raise ValueError("Invalid SNS notification envelope")
        _topic_parts(sns["TopicArn"])
        if sns["Type"] == "SubscriptionConfirmation":
            _validate_token(sns.get("Token"))
        if sns.get("Subject") is not None and not isinstance(sns["Subject"], str):
            raise ValueError("Invalid SNS notification envelope")
        try:
            timestamp = datetime.fromisoformat(sns["Timestamp"].replace("Z", "+00:00"))
            if timestamp.tzinfo is None:
                raise ValueError
        except ValueError:
            raise ValueError("Invalid SNS notification timestamp") from None
        notifications.append(sns)
    return notifications


def _bounded_utf8(text, limit):
    return text.encode("utf-8")[:limit].decode("utf-8", errors="ignore")


def handler(event, context):
    notifications = _notifications(event)
    routing_key = os.environ.get("PAGERDUTY_ROUTING_KEY", "")
    if any(sns["Type"] == "Notification" for sns in notifications) and not routing_key.strip():
        raise RuntimeError("PagerDuty routing key is not configured")
    forwarded = confirmed = 0
    for sns in notifications:
        if sns["Type"] == "SubscriptionConfirmation":
            confirm_subscription(sns["TopicArn"], sns["Token"])
            confirmed += 1
            continue
        message = _bounded_utf8(sns["Message"], 32_768)
        identity = json.dumps([sns["TopicArn"], sns["MessageId"]]).encode("utf-8")
        body = {
            "routing_key": routing_key,
            "event_action": "trigger",
            "dedup_key": "aws-budget-" + hashlib.sha256(identity).hexdigest(),
            "payload": {
                "summary": _bounded_utf8(
                    (sns.get("Subject") or "").strip() or "AWS budget notification", 1024
                ),
                "source": sns["TopicArn"],
                "timestamp": sns["Timestamp"],
                "severity": "warning",
                "custom_details": {
                    "sns_message": message,
                    "sns_message_truncated": message != sns["Message"],
                },
            },
        }
        request = urllib.request.Request(
            "https://events.pagerduty.com/v2/enqueue",
            data=json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                result = json.loads(response.read(65_536))
                if (
                    response.status != 202
                    or not isinstance(result, dict)
                    or result.get("status") != "success"
                ):
                    raise RuntimeError
        except Exception:
            # External errors/responses can contain credentials or notification content.
            # Suppress their context while still failing the invocation for retries/DLQ.
            raise RuntimeError("PagerDuty did not accept the budget notification") from None
        forwarded += 1
    result = {"forwarded": forwarded}
    if confirmed:
        result["confirmed"] = confirmed
    return result
