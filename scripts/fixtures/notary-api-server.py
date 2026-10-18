#!/usr/bin/env python3
"""Loopback-only, credential-free Notary/S3 fixture for shell integration tests."""

import hashlib
import http.server
import json
from pathlib import Path
import sys
import threading
import time
import urllib.parse
import xml.etree.ElementTree as ET

DIRECTORY = Path(sys.argv[1])
DIRECTORY.mkdir()
LOCK = threading.Lock()
STATES = {}
SUBMISSION_ID = "00000000-0000-4000-8000-000000000001"


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body=b"", headers=None):
        if isinstance(body, dict):
            body = json.dumps(body).encode()
        self.send_response(code)
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def handle_request(self):
        parsed = urllib.parse.urlsplit(self.path)
        _, case, path = parsed.path.split("/", 2)
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        with LOCK:
            state = STATES.setdefault(case, {"parts": {}, "tries": {}, "active": 0, "peak": 0})
            with (DIRECTORY / "events.jsonl").open("a") as log:
                log.write(json.dumps({"case": case, "method": self.command, "path": path,
                                      "query": query}) + "\n")
        if path.startswith("notary/v2/submissions"):
            assert self.headers["Authorization"].startswith("Bearer ")
            if self.command == "POST":
                state["submission"] = json.loads(body)
                self.reply(201, {"data": {"id": SUBMISSION_ID, "attributes": {
                    "awsAccessKeyId": "FIXTUREACCESS", "awsSecretAccessKey": "FIXTURESECRET",
                    "awsSessionToken": "FIXTURESESSION", "bucket": "fixture", "object": "file +/artifact"}}})
            elif path.endswith("/logs"):
                self.reply(200, {"data": {"attributes": {
                    "developerLogUrl": "https://logs.example.test/developer/log.json?secret=DO_NOT_PRINT"}}})
            else:
                state["polls"] = state.get("polls", 0) + 1
                verdict = "Invalid" if case == "invalid" else "Accepted"
                if state["polls"] == 1:
                    verdict = "In Progress"
                self.reply(200, {"data": {"id": SUBMISSION_ID, "attributes": {"status": verdict}}})
            return
        assert path == "s3/file +/artifact" or urllib.parse.unquote(path) == "s3/file +/artifact"
        assert self.headers["Authorization"].startswith("AWS4-HMAC-SHA256 ")
        assert self.headers["x-amz-security-token"] == "FIXTURESESSION"
        assert self.headers["x-amz-content-sha256"] == hashlib.sha256(body).hexdigest()
        if self.command in ("POST", "PUT"):
            # A form-encoded POST body is folded into the S3 signature; real S3 rejects the completion.
            content_type = self.headers.get("Content-Type", "")
            assert content_type in ("application/xml", "application/octet-stream"), content_type
            assert "content-type" in self.headers["Authorization"].split("SignedHeaders=")[1].split(",")[0]
        if self.command == "POST" and "uploads" in query:
            self.reply(200, b'<InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
                       b'<UploadId>fixture+upload/id</UploadId></InitiateMultipartUploadResult>')
        elif self.command == "PUT":
            number = int(query["partNumber"][0])
            assert query["uploadId"] == ["fixture+upload/id"]
            with LOCK:
                attempt = state["tries"][number] = state["tries"].get(number, 0) + 1
                state["active"] += 1
                state["peak"] = max(state["peak"], state["active"])
            # Let another failing part exhaust retries first, exercising cancellation.
            time.sleep(0.3 if case == "bad-etag" and number == 1 else 0.1)
            with LOCK:
                state["active"] -= 1
            if number == 1 and (case == "persistent" or (case == "transient" and attempt == 1)):
                self.reply(503, b"FIXTURESECRET FIXTURESESSION DO_NOT_PRINT")
            else:
                state["parts"][number] = body
                etag = hashlib.md5(body).hexdigest() if case != "bad-etag" else "0" * 32
                self.reply(200, headers={"ETag": '"' + etag + '"'})
        elif self.command == "POST":
            parts = ET.fromstring(body).findall("Part")
            assert [int(part.findtext("PartNumber")) for part in parts] == sorted(state["parts"])
            for part in parts:
                number = int(part.findtext("PartNumber"))
                assert part.findtext("ETag") == '"' + hashlib.md5(state["parts"][number]).hexdigest() + '"'
            uploaded = b"".join(state["parts"][number] for number in sorted(state["parts"]))
            assert hashlib.sha256(uploaded).hexdigest() == state["submission"]["sha256"]
            (DIRECTORY / (case + ".uploaded")).write_bytes(uploaded)
            (DIRECTORY / (case + ".stats")).write_text(json.dumps({"peak": state["peak"], "tries": state["tries"]}))
            state["size"] = len(uploaded)
            digests = b"".join(hashlib.md5(state["parts"][number]).digest() for number in sorted(state["parts"]))
            final_etag = hashlib.md5(digests).hexdigest() if case != "bad-final-etag" else "0" * 32
            with LOCK:
                completes = state["completes"] = state.get("completes", 0) + 1
            failing = case == "complete-error-persistent" or (case == "complete-error" and completes == 1)
            self.reply(200, b"<Error><Code>InternalError</Code></Error>" if failing
                       else ('<CompleteMultipartUploadResult><ETag>"%s-%d"</ETag></CompleteMultipartUploadResult>'
                             % (final_etag, len(state["parts"]))).encode())
        elif self.command == "HEAD":
            # The helper must not depend on reading the uploaded object back.
            self.reply(403, b"<Error><Code>AccessDenied</Code></Error>")
        elif self.command == "DELETE":
            self.reply(204)
        else:
            self.reply(400)

    do_GET = do_POST = do_PUT = do_HEAD = do_DELETE = handle_request


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
(DIRECTORY / "port").write_text(str(server.server_port))
server.serve_forever()
