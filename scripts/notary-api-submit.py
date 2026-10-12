#!/usr/bin/env python3
"""Isolated, stdlib-only Notary REST submission and parallel S3 upload."""

import argparse
import base64
import concurrent.futures
import datetime
import hashlib
import hmac
import http.client
import json
import math
from pathlib import Path
import re
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET

API_BASE = "https://appstoreconnect.apple.com/notary/v2"
MIB = 1024 * 1024


class Failure(Exception):
    """Only fixed, credential-free messages may cross the process boundary."""


class TransientFailure(Failure):
    """A connection failure or retryable HTTP status, without response content."""


def der_to_raw(der):
    # P-256 signatures fit short-form DER lengths; reject other encodings.
    if len(der) < 8 or der[0] != 0x30 or der[1] != len(der) - 2:
        raise Failure("invalid P-256 signature")
    values = []
    pos = 2
    for _ in range(2):
        if pos + 2 > len(der) or der[pos] != 2:
            raise Failure("invalid P-256 signature")
        size = der[pos + 1]
        value = der[pos + 2:pos + 2 + size]
        if not value or len(value) != size or value[0] & 0x80:
            raise Failure("invalid P-256 signature")
        if len(value) > 1 and value[0] == 0 and not value[1] & 0x80:
            raise Failure("invalid P-256 signature")
        value = value.lstrip(b"\0")
        if len(value) > 32 or not value:
            raise Failure("invalid P-256 signature")
        values.append(value.rjust(32, b"\0"))
        pos += 2 + size
    if pos != len(der):
        raise Failure("invalid P-256 signature")
    return b"".join(values)


def b64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def make_jwt(key_id, issuer, key_file, now=None):
    now = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    encoded = ".".join(b64url(json.dumps(item, separators=(",", ":")).encode())
                       for item in (header, claims))
    result = subprocess.run(["/usr/bin/openssl", "dgst", "-sha256", "-sign", str(key_file)],
                            input=encoded.encode(), capture_output=True, timeout=15, check=False,
                            env={})
    if result.returncode:
        raise Failure("JWT signing failed")
    return encoded + "." + b64url(der_to_raw(result.stdout))


def sigv4(method, url, headers, payload_hash, access_key, secret_key,
           timestamp, region="us-west-2", service="s3"):
    """Sign already URL-encoded S3 paths (S3 does not normalize object paths)."""
    parsed = urllib.parse.urlsplit(url)
    signed = {key.lower(): " ".join(value.split()) for key, value in headers.items()}
    signed["host"] = parsed.netloc
    signed["x-amz-date"] = timestamp
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    quote = lambda value: urllib.parse.quote(value, safe="-_.~")
    canonical_query = "&".join("%s=%s" % pair for pair in sorted(
        (quote(key), quote(value)) for key, value in query))
    names = ";".join(sorted(signed))
    canonical = "\n".join([method, parsed.path or "/", canonical_query,
                           "".join(key + ":" + signed[key] + "\n" for key in sorted(signed)),
                           names, payload_hash])
    date = timestamp[:8]
    scope = "/".join([date, region, service, "aws4_request"])
    to_sign = "\n".join(["AWS4-HMAC-SHA256", timestamp, scope,
                         hashlib.sha256(canonical.encode()).hexdigest()])
    signing_key = ("AWS4" + secret_key).encode()
    for item in (date, region, service, "aws4_request"):
        signing_key = hmac.new(signing_key, item.encode(), hashlib.sha256).digest()
    signature = hmac.new(signing_key, to_sign.encode(), hashlib.sha256).hexdigest()
    signed["authorization"] = ("AWS4-HMAC-SHA256 Credential=" + access_key + "/" + scope
                               + ", SignedHeaders=" + names + ", Signature=" + signature)
    return signed


def plan_parts(size):
    if size <= 0 or size > 5 * 1024 ** 4:
        raise Failure("submission size outside S3 limits")
    part_size = max(5 * MIB, math.ceil(size / 10000 / MIB) * MIB)
    return [(number + 1, offset, min(part_size, size - offset))
            for number, offset in enumerate(range(0, size, part_size))]


def safe_log_url(url, secrets=()):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        return "[invalid log URL]"
    result = parsed.hostname + urllib.parse.unquote(parsed.path)
    if any(ord(char) < 32 or ord(char) == 127 for char in result):
        return "[invalid log URL]"
    result = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[redacted]", result)
    for secret in secrets:
        if secret:
            result = result.replace(secret, "[redacted]")
    return result


def system_tls_context():
    context = ssl.create_default_context()
    if sys.platform == "darwin":
        # Apple's /usr/bin/python3 may have no OpenSSL CA bundle. Use the shipped roots.
        roots = subprocess.run(["/usr/bin/security", "find-certificate", "-a", "-p",
                                "/System/Library/Keychains/SystemRootCertificates.keychain"],
                               capture_output=True, check=False, timeout=15, env={})
        if roots.returncode:
            raise Failure("could not load system TLS roots")
        context.load_verify_locations(cadata=roots.stdout.decode("ascii"))
    return context


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward Authorization or temporary S3 credentials to another endpoint.
        return None


class Client:
    def __init__(self, args):
        self.args = args
        self.deadline = time.monotonic() + args.timeout
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect(),
            urllib.request.HTTPSHandler(context=system_tls_context()))
        self.stop = threading.Event()

    def remaining(self):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0 or self.stop.is_set():
            raise Failure("submission attempt deadline exceeded or upload cancelled")
        return remaining

    def request(self, method, url, headers, body=None, label="request", cleanup=False,
                request_timeout=60, attempts=4):
        for attempt in range(attempts):
            request = urllib.request.Request(url, data=body,
                                             headers=headers() if callable(headers) else headers, method=method)
            timeout = 30 if cleanup else min(request_timeout, self.remaining())
            try:
                with self.opener.open(request, timeout=timeout) as response:
                    data = response.read(4 * MIB + 1)
                    if len(data) > 4 * MIB:
                        raise Failure(label + " response too large")
                    return response.headers, data
            except urllib.error.HTTPError as error:
                code = error.code
                detail = ""
                if label.startswith("S3"):
                    try:
                        match = re.search(rb"<Code>([A-Za-z]{1,64})</Code>", error.read(64 * 1024))
                        detail = " (" + match.group(1).decode("ascii") + ")" if match else ""
                    except Exception:
                        detail = ""
                error.close()
                message = label + " HTTP " + str(code) + detail
                if code != 429 and not 500 <= code <= 599:
                    raise Failure(message) from None
            except (OSError, urllib.error.URLError, http.client.HTTPException):
                message = label + " connection failed"
            if attempt == attempts - 1:
                raise TransientFailure(message) from None
            if self.stop.wait(min(2 ** attempt, self.remaining())):
                raise Failure("upload cancelled") from None

    def api(self, method, suffix, payload=None):
        def headers():
            token = make_jwt(self.args.key_id, self.args.issuer, self.args.key_file)
            return {"Authorization": "Bearer " + token, "Content-Type": "application/json"}

        _, body = self.request(method, self.args.api_base + suffix,
                               headers,
                               None if payload is None else json.dumps(payload).encode(), "Notary API")
        return json.loads(body)

    def s3(self, attrs, method, operation, query=(), body=None, cleanup=False):
        base = self.args.s3_endpoint or "https://" + attrs["bucket"] + ".s3.us-west-2.amazonaws.com"
        path = "/" + urllib.parse.quote(attrs["object"], safe="/-_.~")
        url = base + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        digest = hashlib.sha256(body or b"").hexdigest()

        def headers():
            unsigned = {"x-amz-content-sha256": digest, "x-amz-security-token": attrs["awsSessionToken"]}
            if body is not None:
                # urllib otherwise adds application/x-www-form-urlencoded, and S3 then folds a POST body into
                # the signed parameters: CompleteMultipartUpload fails with SignatureDoesNotMatch.
                unsigned["content-type"] = ("application/xml" if operation == "CompleteMultipartUpload"
                                            else "application/octet-stream")
            timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            return sigv4(method, url, unsigned, digest, attrs["awsAccessKeyId"],
                         attrs["awsSecretAccessKey"], timestamp)

        # A part can take several minutes on the congested links this path serves.
        # Parts have their own retry loop, and cleanup must work after the deadline.
        return self.request(method, url, headers, body, "S3 " + operation, cleanup,
                            request_timeout=300 if method == "PUT" else 60,
                            attempts=1 if method == "PUT" or cleanup else 4)

    def upload(self, attrs, path):
        size = path.stat().st_size
        parts = plan_parts(size)
        _, body = self.s3(attrs, "POST", "CreateMultipartUpload", [("uploads", "")], b"")
        root = ET.fromstring(body)
        upload_id = next((node.text for node in root.iter() if node.tag.split("}")[-1] == "UploadId"), None)
        if not upload_id:
            raise Failure("S3 did not return an upload ID")
        query = [("uploadId", upload_id)]

        def upload_part(part):
            number, offset, length = part
            with path.open("rb") as source:
                source.seek(offset)
                data = source.read(length)
            if len(data) != length:
                raise Failure("submission changed during upload")
            expected = '"' + hashlib.md5(data).hexdigest() + '"'
            for attempt in range(4):
                try:
                    headers, _ = self.s3(attrs, "PUT", "UploadPart", query + [("partNumber", str(number))], data)
                    if headers.get("ETag", "").lower() != expected:
                        raise Failure("S3 part ETag mismatch")
                    return number, expected
                except Failure as error:
                    if attempt == 3 or (not isinstance(error, TransientFailure)
                                        and str(error) != "S3 part ETag mismatch"):
                        self.stop.set()
                        raise
                    if self.stop.wait(min(2 ** attempt, self.remaining())):
                        raise Failure("upload cancelled") from None

        completed = False
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=self.args.parallelism) as pool:
                results = sorted(pool.map(upload_part, parts))
            complete = ET.Element("CompleteMultipartUpload")
            for number, etag in results:
                part = ET.SubElement(complete, "Part")
                ET.SubElement(part, "PartNumber").text = str(number)
                ET.SubElement(part, "ETag").text = etag
            for attempt in range(4):
                _, body = self.s3(attrs, "POST", "CompleteMultipartUpload", query, ET.tostring(complete))
                result = ET.fromstring(body)
                tag = result.tag.split("}")[-1]
                if tag == "CompleteMultipartUploadResult":
                    break
                code = next((node.text for node in result.iter() if node.tag.split("}")[-1] == "Code"), "") or ""
                code = code if re.fullmatch(r"[A-Za-z]{1,64}", code) else ""
                # S3 can report a failed completion inside HTTP 200; AWS documents retrying these errors.
                if tag != "Error" or code not in ("InternalError", "ServiceUnavailable", "SlowDown") or attempt == 3:
                    raise Failure("S3 multipart completion failed" + (" (" + code + ")" if code else ""))
                time.sleep(min(2 ** attempt, self.remaining()))
            completed = True
            # Bind the stored object to the uploaded parts through the multipart ETag instead of reading it
            # back with the narrowly scoped upload credentials; Apple re-checks the submission sha256.
            final_etag = next((node.text for node in result.iter() if node.tag.split("}")[-1] == "ETag"), "")
            expected = '"%s-%d"' % (hashlib.md5(b"".join(bytes.fromhex(etag.strip('"'))
                                                       for _, etag in results)).hexdigest(), len(results))
            if (final_etag or "").lower() != expected:
                raise Failure("S3 multipart ETag mismatch")
        except BaseException:
            self.stop.set()
            if not completed:
                try:
                    self.s3(attrs, "DELETE", "AbortMultipartUpload", query, cleanup=True)
                except Exception:
                    print("notary-api: multipart abort failed", file=sys.stderr)
            raise

    def submit(self):
        path = Path(self.args.artifact)
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for block in iter(lambda: source.read(MIB), b""):
                digest.update(block)
        data = self.api("POST", "/submissions", {"sha256": digest.hexdigest(),
                                                "submissionName": self.args.submission_name})["data"]
        submission_id = str(uuid.UUID(data["id"]))
        credentials = data["attributes"]
        self.upload(credentials, path)
        while True:
            data = self.api("GET", "/submissions/" + submission_id)["data"]
            status = data["attributes"]["status"]
            if status not in ("In Progress", "Accepted", "Invalid", "Rejected"):
                raise Failure("Notary API returned an unknown status")
            if status != "In Progress":
                if status in ("Invalid", "Rejected"):
                    try:
                        logs = self.api("GET", "/submissions/" + submission_id + "/logs")
                        log_url = logs["data"]["attributes"]["developerLogUrl"]
                        secrets = [credentials[field] for field in
                                   ("awsAccessKeyId", "awsSecretAccessKey", "awsSessionToken")]
                        print("notary-api: developer log " + safe_log_url(log_url, secrets), file=sys.stderr)
                    except Exception:
                        print("notary-api: could not retrieve developer log URL", file=sys.stderr)
                return {"id": submission_id, "status": status}
            time.sleep(min(self.args.poll_interval, self.remaining()))


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", required=True)
    parser.add_argument("--submission-name", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer", required=True)
    parser.add_argument("--key-file", required=True)
    parser.add_argument("--parallelism", type=int, default=24)
    parser.add_argument("--timeout", type=int, default=3600)
    parser.add_argument("--poll-interval", type=float)
    parser.add_argument("--fixture-profile")
    parser.add_argument("--api-base")
    parser.add_argument("--s3-endpoint")
    args = parser.parse_args(argv)
    if args.fixture_profile != "__peekaboo_fixture__":
        if (args.fixture_profile is not None or args.api_base is not None
                or args.s3_endpoint is not None or args.poll_interval is not None):
            parser.error("endpoint and polling overrides are fixture-only")
    else:
        for endpoint in (args.api_base, args.s3_endpoint):
            parsed = urllib.parse.urlsplit(endpoint or "")
            if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1" or not parsed.port
                    or parsed.username or parsed.password or parsed.query or parsed.fragment):
                parser.error("fixture endpoints must be loopback HTTP URLs")
    args.api_base = args.api_base or API_BASE
    args.poll_interval = 10 if args.poll_interval is None else args.poll_interval
    if not 1 <= args.parallelism <= 24 or not 1 <= args.timeout <= 3600 or not 0 < args.poll_interval <= 60:
        parser.error("invalid submission bounds")
    return args


def main():
    try:
        print(json.dumps(Client(parse_args()).submit()))
        return 0
    except Failure as error:
        print("notary-api: " + str(error), file=sys.stderr)
    except Exception:
        # Never stringify remote JSON/XML, HTTP errors, URLs, or signer stderr.
        print("notary-api: invalid response or local submission failure", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
