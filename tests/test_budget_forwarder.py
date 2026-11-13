import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import traceback
import unittest
from unittest import mock
import urllib.error
import urllib.parse


HANDLER = Path(__file__).resolve().parents[1] / "scripts/aws-budget-forwarder/handler.py"


class Response(io.BytesIO):
    def __init__(self, status=202, body=b'{"status":"success"}'):
        super().__init__(body)
        self.status = status


class BudgetForwarderTest(unittest.TestCase):
    def setUp(self):
        if not HANDLER.exists():
            self.fail("The AWS budget forwarder has not been implemented")
        spec = importlib.util.spec_from_file_location("budget_forwarder", HANDLER)
        self.forwarder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.forwarder)
        self.key = "test-routing-key-never-log"
        self.environment = mock.patch.dict(os.environ, {"PAGERDUTY_ROUTING_KEY": self.key})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.requests = []

        def accept(request, *, timeout):
            self.requests.append(request)
            self.assertGreater(timeout, 0)
            return Response()

        self.http = mock.patch("urllib.request.urlopen", side_effect=accept)
        self.http_mock = self.http.start()
        self.addCleanup(self.http.stop)

    def event(self, **sns_changes):
        sns = {
            "Type": "Notification",
            "TopicArn": "arn:aws:sns:us-east-1:123456789012:budget-alerts",
            "MessageId": "message-one",
            "Subject": "AWS Budgets: monthly threshold exceeded",
            "Timestamp": "2026-11-12T23:45:00.000Z",
            "Message": "Monthly budget actual spend exceeded 90%.",
        }
        sns.update(sns_changes)
        return {"Records": [{"EventSource": "aws:sns", "Sns": sns}]}

    def sent(self):
        return [json.loads(request.data) for request in self.requests]

    def test_sends_budget_text_as_a_pagerduty_event(self):
        result = self.forwarder.handler(self.event(), None)

        self.assertEqual(result, {"forwarded": 1})
        self.assertEqual(len(self.requests), 1)
        request = self.requests[0]
        self.assertEqual(request.full_url, "https://events.pagerduty.com/v2/enqueue")
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(request.get_header("Content-type"), "application/json")
        event = self.sent()[0]
        self.assertEqual(event["routing_key"], self.key)
        self.assertEqual(event["event_action"], "trigger")
        self.assertEqual(
            event["payload"],
            {
                "summary": "AWS Budgets: monthly threshold exceeded",
                "source": "arn:aws:sns:us-east-1:123456789012:budget-alerts",
                "timestamp": "2026-11-12T23:45:00.000Z",
                "severity": "warning",
                "custom_details": {
                    "sns_message": "Monthly budget actual spend exceeded 90%.",
                    "sns_message_truncated": False,
                },
            },
        )

    def test_retries_have_stable_dedup_without_collapsing_distinct_notifications(self):
        event = self.event()
        self.forwarder.handler(event, None)
        self.forwarder.handler(event, None)
        self.forwarder.handler(self.event(MessageId="next-threshold-or-month"), None)
        self.forwarder.handler(
            self.event(TopicArn="arn:aws:sns:us-east-1:987654321098:budget-alerts"), None
        )

        sent = self.sent()
        self.assertIn("dedup_key", sent[0])
        self.assertEqual(sent[0]["dedup_key"], sent[1]["dedup_key"])
        self.assertNotEqual(sent[0]["dedup_key"], sent[2]["dedup_key"])
        self.assertNotEqual(sent[0]["dedup_key"], sent[3]["dedup_key"])
        self.assertLessEqual(len(sent[0]["dedup_key"]), 255)

    def test_json_notification_remains_unmodified_text(self):
        message = '{ "budget": "monthly", "threshold": 90, "notes": "€" }\n'
        self.forwarder.handler(self.event(Message=message), None)
        self.assertEqual(self.sent()[0]["payload"]["custom_details"]["sns_message"], message)

    def test_subject_falls_back_when_absent_empty_or_null(self):
        for subject in [None, "", "   "]:
            with self.subTest(subject=subject):
                self.forwarder.handler(self.event(Subject=subject), None)
                summary = self.sent()[-1]["payload"]["summary"]
                self.assertIsInstance(summary, str)
                self.assertTrue(summary.strip())
        event = self.event()
        del event["Records"][0]["Sns"]["Subject"]
        self.forwarder.handler(event, None)
        self.assertTrue(self.sent()[-1]["payload"]["summary"])

    def test_oversized_unicode_message_and_summary_are_bounded_without_invalid_utf8(self):
        message = "Budget € " + "🚨" * 20_000
        self.forwarder.handler(self.event(Message=message, Subject="🚨" * 1000), None)

        payload = self.sent()[0]["payload"]
        details = payload["custom_details"]
        self.assertTrue(details["sns_message_truncated"])
        self.assertLessEqual(len(details["sns_message"].encode("utf-8")), 32_768)
        self.assertTrue(message.startswith(details["sns_message"]))
        self.assertNotIn("\ufffd", details["sns_message"])
        self.assertLessEqual(len(payload["summary"].encode("utf-8")), 1024)
        self.assertNotIn("\ufffd", payload["summary"])

    def test_malformed_envelopes_never_reach_http(self):
        invalid = [None, [], {}, {"Records": []}, {"Records": "wrong"}]
        for field, value in [
            ("Message", None),
            ("Message", {}),
            ("Message", ""),
            ("MessageId", ""),
            ("MessageId", 1),
            ("TopicArn", "not-an-sns-topic"),
            ("Timestamp", "not-a-timestamp"),
            ("Timestamp", "2026-11-12"),
            ("Subject", []),
            ("Type", "SubscriptionConfirmation"),
        ]:
            invalid.append(self.event(**{field: value}))
        invalid.extend(
            [
                {"Records": [None]},
                {"Records": [{"EventSource": "aws:sqs", "Sns": {}}]},
                {"Records": [{"EventSource": "aws:sns", "Sns": None}]},
            ]
        )
        for event in invalid:
            with self.subTest(event=event):
                try:
                    self.forwarder.handler(event, None)
                except Exception as error:
                    self.assertIsInstance(error, ValueError)
                else:
                    self.fail("Malformed SNS notification was accepted")
                self.assertEqual(self.requests, [])

    def test_entire_batch_is_validated_before_any_delivery(self):
        event = self.event()
        event["Records"].append({"EventSource": "aws:sns", "Sns": {}})
        try:
            self.forwarder.handler(event, None)
        except Exception as error:
            self.assertIsInstance(error, ValueError)
        else:
            self.fail("Malformed batch was accepted")
        self.assertEqual(self.requests, [])

    def test_missing_routing_key_never_reaches_http(self):
        for key in ["", "   "]:
            with self.subTest(key=key), mock.patch.dict(
                os.environ, {"PAGERDUTY_ROUTING_KEY": key}
            ):
                with self.assertRaises(RuntimeError):
                    self.forwarder.handler(self.event(), None)
                self.assertEqual(self.requests, [])

    def test_requires_both_http_202_and_success_json(self):
        for status, body in [
            (200, b'{"status":"success"}'),
            (202, b'{"status":"error","message":"private-response"}'),
            (202, b"not json"),
            (202, b"[]"),
            (202, b"null"),
        ]:
            with self.subTest(status=status, body=body):
                self.http_mock.side_effect = lambda *args, **kwargs: Response(status, body)
                with self.assertRaises(RuntimeError) as caught:
                    self.forwarder.handler(self.event(), None)
                self.assertNotIn("private-response", str(caught.exception))

    def test_http_and_network_failures_are_sanitized_and_propagate(self):
        errors = [
            urllib.error.HTTPError(
                "https://events.pagerduty.com/v2/enqueue", 429, self.key, {}, None
            ),
            urllib.error.URLError(self.key),
            TimeoutError(self.key),
        ]
        for failure in errors:
            with self.subTest(failure=type(failure).__name__):
                self.http_mock.side_effect = failure
                try:
                    self.forwarder.handler(self.event(), None)
                except Exception as error:
                    self.assertIsInstance(error, RuntimeError)
                    rendered = "".join(traceback.format_exception(error))
                    self.assertNotIn(self.key, rendered)
                    self.assertNotIn("Monthly budget actual spend", rendered)
                else:
                    self.fail("Delivery failure did not propagate for Lambda retry")

    def test_processes_every_notification_in_a_valid_batch(self):
        event = self.event()
        second = copy.deepcopy(event["Records"][0])
        second["Sns"]["MessageId"] = "message-two"
        second["Sns"]["Message"] = "A different budget notification"
        event["Records"].append(second)

        self.assertEqual(self.forwarder.handler(event, None), {"forwarded": 2})
        self.assertEqual(len(self.sent()), 2)
        self.assertEqual(
            self.sent()[1]["payload"]["custom_details"]["sns_message"],
            "A different budget notification",
        )

    def confirmation(self, **changes):
        return self.event(
            Type="SubscriptionConfirmation",
            Token="private-confirmation-token+/=",
            SubscribeUrl="https://malicious.invalid/never-follow-this",
            **changes,
        )

    def confirmation_response(self, topic=None):
        topic = topic or "arn:aws:sns:us-east-1:123456789012:budget-alerts"
        return Response(
            200,
            (
                '<ConfirmSubscriptionResponse xmlns="http://sns.amazonaws.com/doc/2010-03-31/">'
                "<ConfirmSubscriptionResult><SubscriptionArn>"
                + topic
                + ":subscription-id</SubscriptionArn></ConfirmSubscriptionResult>"
                "</ConfirmSubscriptionResponse>"
            ).encode(),
        )

    def test_confirms_observed_sns_control_event_without_following_supplied_url(self):
        def confirm(request, *, timeout):
            self.requests.append(request)
            return self.confirmation_response()

        self.http_mock.side_effect = confirm
        result = self.forwarder.handler(self.confirmation(), None)

        self.assertEqual(result, {"forwarded": 0, "confirmed": 1})
        self.assertEqual(len(self.requests), 1)
        request = self.requests[0]
        self.assertEqual(request.full_url, "https://sns.us-east-1.amazonaws.com/")
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(
            request.get_header("Content-type"), "application/x-www-form-urlencoded"
        )
        self.assertEqual(
            urllib.parse.parse_qs(request.data.decode()),
            {
                "Action": ["ConfirmSubscription"],
                "Version": ["2010-03-31"],
                "TopicArn": ["arn:aws:sns:us-east-1:123456789012:budget-alerts"],
                "Token": ["private-confirmation-token+/="],
            },
        )

    def test_confirmation_does_not_require_a_pagerduty_key(self):
        self.http_mock.side_effect = lambda *a, **k: self.confirmation_response()
        with mock.patch.dict(os.environ, {"PAGERDUTY_ROUTING_KEY": ""}):
            self.assertEqual(
                self.forwarder.handler(self.confirmation(), None),
                {"forwarded": 0, "confirmed": 1},
            )

    def test_bad_confirmation_token_invalidates_the_entire_mixed_batch(self):
        for token in [None, "", "  ", 123]:
            with self.subTest(token=token):
                event = self.event()
                confirmation = self.confirmation()["Records"][0]
                confirmation["Sns"]["Token"] = token
                event["Records"].append(confirmation)
                with self.assertRaises(ValueError):
                    self.forwarder.handler(event, None)
                self.assertEqual(self.requests, [])

    def test_confirmation_requires_http_200_and_matching_subscription_xml(self):
        for status, body in [
            (202, b"<SubscriptionArn>ignored</SubscriptionArn>"),
            (200, b"not xml"),
            (200, b"<ConfirmSubscriptionResponse/>"),
            (200, b"<SubscriptionArn>arn:aws:sns:us-east-1:111111111111:other:id</SubscriptionArn>"),
        ]:
            with self.subTest(status=status, body=body):
                self.http_mock.side_effect = lambda *a, **k: Response(status, body)
                with self.assertRaises(RuntimeError) as caught:
                    self.forwarder.handler(self.confirmation(), None)
                self.assertNotIn("private-confirmation-token", str(caught.exception))

    def test_confirmation_network_failures_are_sanitized_for_lambda_retry(self):
        self.http_mock.side_effect = urllib.error.URLError("private-confirmation-token")
        with self.assertRaises(RuntimeError) as caught:
            self.forwarder.handler(self.confirmation(), None)
        self.assertNotIn(
            "private-confirmation-token", "".join(traceback.format_exception(caught.exception))
        )

    def test_confirms_china_partition_using_its_regional_aws_domain(self):
        topic = "arn:aws-cn:sns:cn-north-1:123456789012:budget-alerts"

        def confirm(request, *, timeout):
            self.requests.append(request)
            return self.confirmation_response(topic)

        self.http_mock.side_effect = confirm
        self.forwarder.handler(self.confirmation(TopicArn=topic), None)
        self.assertEqual(self.requests[0].full_url, "https://sns.cn-north-1.amazonaws.com.cn/")

    def test_mixed_batch_confirms_control_and_forwards_only_the_notification(self):
        def accept(request, *, timeout):
            self.requests.append(request)
            if request.full_url.startswith("https://sns."):
                return self.confirmation_response()
            return Response()

        self.http_mock.side_effect = accept
        event = self.confirmation()
        event["Records"].extend(self.event()["Records"])

        self.assertEqual(self.forwarder.handler(event, None), {"forwarded": 1, "confirmed": 1})
        self.assertEqual(len(self.requests), 2)
        pd_request = self.requests[1]
        self.assertEqual(pd_request.full_url, "https://events.pagerduty.com/v2/enqueue")
        self.assertNotIn(b"private-confirmation-token", pd_request.data)


if __name__ == "__main__":
    unittest.main()
