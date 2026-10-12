#!/usr/bin/env python3
"""Offline cryptographic and boundary tests for the Notary REST helper."""

import base64
import contextlib
import io
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, Mock, patch

SPEC = importlib.util.spec_from_file_location("notary_api", Path(__file__).with_name("notary-api-submit.py"))
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)


def decode(part):
    return base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))


class NotaryTests(unittest.TestCase):
    def test_aws_published_iam_vector(self):
        # AWS IAM ListUsers example, "Signature Version 4 signing process".
        headers = api.sigv4("GET", "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08",
                            {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
                            api.hashlib.sha256(b"").hexdigest(), "AKIDEXAMPLE",
                            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY", "20150830T123600Z",
                            region="us-east-1", service="iam")
        self.assertEqual(headers["authorization"].split("Signature=")[1],
                         "5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7")

    def test_der(self):
        # Both a sign-padding byte and a short integer must become exactly 32 bytes.
        value = bytes.fromhex("80" + "01" * 31)
        der = b"\x30\x26\x02\x21\0" + value + b"\x02\x01\x01"
        self.assertEqual(api.der_to_raw(der), value + b"\0" * 31 + b"\x01")
        for invalid in (b"", der + b"\0", der[:-1], b"\x30\x06\x02\x01\x80\x02\x01\x01",
                        b"\x30\x07\x02\x02\0\x01\x02\x01\x01"):
            with self.assertRaises(api.Failure):
                api.der_to_raw(invalid)

    def test_jwt_with_throwaway_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp) / "throwaway.pem"
            public = Path(tmp) / "public.pem"
            subprocess.run(["/usr/bin/openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout",
                            "-out", str(key)], check=True, capture_output=True)
            subprocess.run(["/usr/bin/openssl", "pkey", "-in", str(key), "-pubout", "-out", str(public)],
                           check=True, capture_output=True)
            token = api.make_jwt("FIXTURE", "issuer", key, 1000)
            header, claims, signature = token.split(".")
            self.assertEqual(json.loads(decode(header)), {"alg": "ES256", "kid": "FIXTURE", "typ": "JWT"})
            self.assertEqual(json.loads(decode(claims)),
                             {"iss": "issuer", "iat": 1000, "exp": 1600, "aud": "appstoreconnect-v1"})
            raw = decode(signature)
            self.assertEqual(len(raw), 64)
            integers = []
            for half in (raw[:32], raw[32:]):
                half = half.lstrip(b"\0")
                if half[0] & 0x80:
                    half = b"\0" + half
                integers.append(b"\x02" + bytes([len(half)]) + half)
            body = b"".join(integers)
            sigfile = Path(tmp) / "signature.der"
            sigfile.write_bytes(b"\x30" + bytes([len(body)]) + body)
            verify = subprocess.run(["/usr/bin/openssl", "dgst", "-sha256", "-verify", str(public),
                                     "-signature", str(sigfile)], input=(header + "." + claims).encode(),
                                    capture_output=True)
            self.assertEqual(verify.returncode, 0)

    def test_parts(self):
        self.assertEqual(api.plan_parts(40 * api.MIB),
                         [(number + 1, number * 5 * api.MIB, 5 * api.MIB) for number in range(8)])
        for size in (1, 5 * api.MIB, 8 * api.MIB, 17 * api.MIB + 7, 5 * 1024 ** 4):
            parts = api.plan_parts(size)
            self.assertLessEqual(len(parts), 10000)
            self.assertEqual(sum(part[2] for part in parts), size)
            self.assertEqual(parts[0][1], 0)
            for index, (number, offset, length) in enumerate(parts):
                self.assertEqual(number, index + 1)
                if index:
                    self.assertEqual(offset, parts[index - 1][1] + parts[index - 1][2])
                if index < len(parts) - 1:
                    self.assertGreaterEqual(length, 5 * api.MIB)
        for size in (0, -1, 5 * 1024 ** 4 + 1):
            with self.assertRaises(api.Failure):
                api.plan_parts(size)

    def test_redaction(self):
        self.assertEqual(api.safe_log_url("https://user:password@logs.example/path?token=SECRET#signature"),
                         "logs.example/path")
        self.assertEqual(api.safe_log_url("https://logs.example/SECRET", ["SECRET"]),
                         "logs.example/[redacted]")
        self.assertEqual(api.safe_log_url("https://logs.example/a%2Bb", ["a+b"]),
                         "logs.example/[redacted]")
        self.assertEqual(api.safe_log_url("https://logs.example/eyJheader.payload.signature"),
                         "logs.example/[redacted]")
        self.assertEqual(api.safe_log_url("http://logs.example/path"), "[invalid log URL]")

    def test_deadline_and_no_credential_redirects(self):
        client = api.Client.__new__(api.Client)
        client.stop = api.threading.Event()
        client.deadline = 5
        with patch.object(api.time, "monotonic", return_value=6), self.assertRaises(api.Failure):
            client.remaining()
        self.assertIsNone(api.NoRedirect().redirect_request(None, None, 302, None, None,
                                                           "https://untrusted.example"))

    def test_jwt_regenerated_for_each_api_request(self):
        client = api.Client.__new__(api.Client)
        client.args = api.argparse.Namespace(key_id="fixture", issuer="fixture", key_file="unused",
                                            api_base=api.API_BASE)
        seen = []
        client.request = lambda method, url, headers, body, label: (seen.append(headers()) or ({}, b"{}"))
        with patch.object(api, "make_jwt", side_effect=["first", "second"]):
            client.api("GET", "/submissions/fixture")
            client.api("GET", "/submissions/fixture")
        self.assertEqual([headers["Authorization"] for headers in seen], ["Bearer first", "Bearer second"])

    def test_request_retries_and_auth_failures(self):
        # Cover submission creation, polling, logs, and multipart creation/completion.
        for method, path in (("POST", "/submissions"), ("GET", "/submissions/id"),
                             ("GET", "/submissions/id/logs"), ("POST", "/s3?uploads="),
                             ("POST", "/s3?uploadId=id")):
            for code in (503, 429, 403, 422):
                with self.subTest(method=method, path=path, code=code):
                    client = api.Client.__new__(api.Client)
                    client.deadline = api.time.monotonic() + 60
                    client.stop = Mock()
                    client.stop.is_set.return_value = False
                    client.stop.wait.return_value = False
                    client.opener = MagicMock()
                    response = client.opener.open.return_value.__enter__.return_value
                    response.headers = {"fixture": "ok"}
                    response.read.return_value = b"{}"
                    error = api.urllib.error.HTTPError("https://fixture.invalid", code, "secret", {}, None)
                    client.opener.open.side_effect = [error, client.opener.open.return_value]
                    if code in (503, 429):
                        self.assertEqual(client.request(method, "https://fixture.invalid" + path, {}),
                                         ({"fixture": "ok"}, b"{}"))
                        self.assertEqual(client.opener.open.call_count, 2)
                        client.stop.wait.assert_called_once_with(1)
                    else:
                        with self.assertRaisesRegex(api.Failure, "HTTP " + str(code)):
                            client.request(method, "https://fixture.invalid" + path, {})
                        self.assertEqual(client.opener.open.call_count, 1)
                        client.stop.wait.assert_not_called()

    def test_connection_retries_are_bounded_and_deadline_limited(self):
        client = api.Client.__new__(api.Client)
        client.deadline = api.time.monotonic() + 60
        client.stop = Mock()
        client.stop.is_set.return_value = False
        client.stop.wait.return_value = False
        client.opener = MagicMock()
        client.opener.open.side_effect = OSError("secret")
        with self.assertRaisesRegex(api.TransientFailure, "^request connection failed$"):
            client.request("POST", "https://fixture.invalid", {})
        self.assertEqual(client.opener.open.call_count, 4)
        self.assertEqual([call.args[0] for call in client.stop.wait.call_args_list], [1, 2, 4])
        client.opener.reset_mock()
        client.stop.wait.reset_mock()
        with patch.object(api.time, "monotonic", side_effect=[client.deadline - 0.1,
                                                              client.deadline - 0.05,
                                                              client.deadline + 0.1]):
            with self.assertRaisesRegex(api.Failure, "deadline"):
                client.request("GET", "https://fixture.invalid", {})
        self.assertEqual(client.opener.open.call_count, 1)
        self.assertAlmostEqual(client.stop.wait.call_args.args[0], 0.05, places=5)

    def test_retry_refreshes_jwt(self):
        client = api.Client.__new__(api.Client)
        client.deadline = api.time.monotonic() + 60
        client.stop = Mock()
        client.stop.is_set.return_value = False
        client.stop.wait.return_value = False
        client.args = api.argparse.Namespace(key_id="fixture", issuer="fixture", key_file="unused",
                                            api_base=api.API_BASE)
        client.opener = MagicMock()
        response = client.opener.open.return_value.__enter__.return_value
        response.read.return_value = b"{}"
        client.opener.open.side_effect = [OSError(), client.opener.open.return_value]
        with patch.object(api, "make_jwt", side_effect=["first", "second"]):
            client.api("POST", "/submissions", {})
        self.assertEqual([call.args[0].get_header("Authorization")
                          for call in client.opener.open.call_args_list], ["Bearer first", "Bearer second"])

    def test_slow_part_timeout_and_error_redaction(self):
        client = api.Client.__new__(api.Client)
        client.stop = api.threading.Event()
        client.deadline = api.time.monotonic() + 1000
        client.args = api.argparse.Namespace(s3_endpoint="http://127.0.0.1:1")
        client.opener = MagicMock()
        client.opener.open.side_effect = api.http.client.IncompleteRead(b"SECRET_RESPONSE")
        attrs = {"object": "file", "awsAccessKeyId": "fixture", "awsSecretAccessKey": "secret",
                 "awsSessionToken": "token"}
        with self.assertRaisesRegex(api.Failure, "^S3 UploadPart connection failed$"):
            client.s3(attrs, "PUT", "UploadPart", body=b"part")
        self.assertEqual(client.opener.open.call_args.kwargs["timeout"], 300)
        client.deadline = api.time.monotonic() + 15
        with self.assertRaises(api.Failure):
            client.s3(attrs, "PUT", "UploadPart", body=b"part")
        self.assertLessEqual(client.opener.open.call_args.kwargs["timeout"], 15)

    def test_s3_failures_name_operation_and_safe_error_code(self):
        client = api.Client.__new__(api.Client)
        client.stop = api.threading.Event()
        client.deadline = api.time.monotonic() + 60
        client.args = api.argparse.Namespace(s3_endpoint="http://127.0.0.1:1")
        attrs = {"object": "file", "awsAccessKeyId": "fixture", "awsSecretAccessKey": "secret",
                 "awsSessionToken": "token"}
        for body, expected in ((b"<Error><Code>AccessDenied</Code><Message>SECRET</Message></Error>",
                                "^S3 CompleteMultipartUpload HTTP 403 \\(AccessDenied\\)$"),
                               (b"<Error><Code>Access Denied SECRET</Code></Error>",
                                "^S3 CompleteMultipartUpload HTTP 403$")):
            with self.subTest(body=body):
                client.opener = MagicMock()
                client.opener.open.side_effect = api.urllib.error.HTTPError(
                    "https://fixture.invalid", 403, "SECRET", {}, io.BytesIO(body))
                with self.assertRaisesRegex(api.Failure, expected):
                    client.s3(attrs, "POST", "CompleteMultipartUpload", [("uploadId", "id")], b"<x/>")

    def test_s3_bodies_carry_signed_explicit_content_type(self):
        client = api.Client.__new__(api.Client)
        client.args = api.argparse.Namespace(s3_endpoint="http://127.0.0.1:1")
        attrs = {"object": "file", "awsAccessKeyId": "fixture", "awsSecretAccessKey": "secret",
                 "awsSessionToken": "token"}
        seen = {}
        client.request = lambda method, url, headers, body, label, cleanup, **_: seen.update(
            {label: headers()}) or ({}, b"")
        client.s3(attrs, "POST", "CompleteMultipartUpload", [("uploadId", "id")], b"<x/>")
        client.s3(attrs, "PUT", "UploadPart", [("uploadId", "id"), ("partNumber", "1")], b"part")
        client.s3(attrs, "DELETE", "AbortMultipartUpload", [("uploadId", "id")], cleanup=True)
        for label, expected in (("S3 CompleteMultipartUpload", "application/xml"),
                                ("S3 UploadPart", "application/octet-stream")):
            self.assertEqual(seen[label]["content-type"], expected)
            self.assertIn("content-type;", seen[label]["authorization"].split("SignedHeaders=")[1])
        self.assertNotIn("content-type", seen["S3 AbortMultipartUpload"])

    def test_multipart_etag_binds_completed_object(self):
        client = api.Client.__new__(api.Client)
        client.stop = api.threading.Event()
        client.deadline = api.time.monotonic() + 60
        client.args = api.argparse.Namespace(parallelism=4)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "artifact.zip"
            path.write_bytes(b"a" * (5 * api.MIB) + b"b")
            parts = [b"a" * (5 * api.MIB), b"b"]
            good = api.hashlib.md5(b"".join(api.hashlib.md5(part).digest() for part in parts)).hexdigest()
            for final, error in (('"%s-2"' % good, None), ('"%s-2"' % ("0" * 32), "S3 multipart ETag mismatch")):
                with self.subTest(final=final):
                    calls = []

                    def fake_s3(attrs, method, operation, query=(), body=None, cleanup=False):
                        calls.append(operation)
                        if operation == "CreateMultipartUpload":
                            return {}, b"<InitiateMultipartUploadResult><UploadId>id</UploadId></InitiateMultipartUploadResult>"
                        if operation == "UploadPart":
                            return {"ETag": '"' + api.hashlib.md5(body).hexdigest() + '"'}, b""
                        if operation == "CompleteMultipartUpload":
                            return {}, ("<CompleteMultipartUploadResult><ETag>%s</ETag>"
                                        "</CompleteMultipartUploadResult>" % final).encode()
                        return {}, b""

                    client.stop = api.threading.Event()
                    client.s3 = fake_s3
                    if error:
                        with self.assertRaisesRegex(api.Failure, error):
                            client.upload({}, path)
                    else:
                        client.upload({}, path)
                    # Completed uploads are never aborted, and nothing reads the object back.
                    self.assertNotIn("AbortMultipartUpload", calls)
                    self.assertEqual(calls.count("UploadPart"), 2)

    def test_fixture_override_boundary(self):
        args = ["--artifact", "unused", "--submission-name", "fixture", "--key-id", "fixture",
                "--issuer", "fixture", "--key-file", "unused"]
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            api.parse_args(args + ["--api-base", "http://127.0.0.1:1234/notary/v2"])
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            api.parse_args(args + ["--api-base", api.API_BASE])
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            api.parse_args(args + ["--fixture-profile", "__peekaboo_fixture__",
                                  "--api-base", "https://external.example", "--s3-endpoint", "http://127.0.0.1:1"])


if __name__ == "__main__":
    unittest.main()
