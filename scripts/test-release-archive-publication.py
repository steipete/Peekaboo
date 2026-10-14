#!/usr/bin/env python3
"""Exercise release archive publication with real ditto write failures."""
import hashlib
import os
from pathlib import Path
import resource
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    assert result.returncode == 0, (args, result.returncode, result.stderr)
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


failures = []

with tempfile.TemporaryDirectory(prefix="peekaboo-archive-publication.") as directory:
    temporary = Path(directory)
    release = temporary / "release"
    release.mkdir()

    app = temporary / "Fixture.app"
    contents = app / "Contents"
    contents.mkdir(parents=True)
    (contents / "payload").write_bytes(os.urandom(65536))
    zip_archive = release / "Fixture.zip"
    producer = ROOT / "scripts/create-app-zip.sh"
    run(["bash", str(producer), str(app), str(zip_archive)])
    run(["/usr/bin/unzip", "-t", str(zip_archive)])
    before = digest(zip_archive)

    def limit_archive_size():
        resource.setrlimit(resource.RLIMIT_FSIZE, (1024, 1024))

    result = subprocess.run(
        ["bash", str(producer), str(app), str(zip_archive)],
        capture_output=True, text=True, preexec_fn=limit_archive_size,
    )
    assert result.returncode != 0, "native ditto size limit must fail"
    if digest(zip_archive) != before:
        failures.append("failed ZIP publication replaced the previous archive")
    assert sorted(path.name for path in release.iterdir()) == [zip_archive.name], "ZIP temporary leaked"
    (contents / "payload").write_bytes(b"replacement payload")
    run(["bash", str(producer), str(app), str(zip_archive)])
    extracted = temporary / "extracted"
    run(["/usr/bin/ditto", "-x", "-k", str(zip_archive), str(extracted)])
    assert (extracted / "Fixture.app/Contents/payload").read_bytes() == b"replacement payload"
    print("CHECK app ZIP: native success and actual size-limit failure (preservation assertions below)")

assert not failures, failures
print("PASS native app ZIP publication contract")
