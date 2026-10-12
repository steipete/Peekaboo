#!/usr/bin/env python3
"""Offline integration coverage of the shared public-release notary boundary."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
SUBMISSION_ID = '00000000-0000-4000-8000-000000000001'


class SubmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='peekaboo-notary-submit-')
        cls.root = Path(cls.tmp.name)
        cls.bin = cls.root / 'bin'
        cls.bin.mkdir()
        cls.key = cls.root / 'fixture.p8'
        subprocess.run(['/usr/bin/openssl', 'genpkey', '-algorithm', 'EC', '-pkeyopt',
                        'ec_paramgen_curve:P-256', '-out', str(cls.key)], check=True, capture_output=True)
        cls.artifact = cls.root / 'artifact.zip'
        cls.artifact.write_bytes(b'fixture bytes\0' * 900000)
        cls.server = subprocess.Popen(['/usr/bin/python3', '-I', str(ROOT / 'scripts/fixtures/notary-api-server.py'),
                                       str(cls.root / 'server')], stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL, env={})
        for _ in range(100):
            port = cls.root / 'server/port'
            if port.exists():
                break
            if cls.server.poll() is not None:
                raise RuntimeError('fixture server exited')
            time.sleep(0.02)
        cls.base = 'http://127.0.0.1:' + port.read_text()
        fake = cls.bin / 'xcrun'
        fake.write_text('''#!/usr/bin/python3
import json, os, pathlib, stat, sys
args = sys.argv[1:]
if args[:2] == ['stapler', 'staple']:
    counter = pathlib.Path(os.environ['CASE_DIR']) / 'staples'
    count = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(count))
    sys.exit(0 if count >= int(os.environ.get('STAPLE_SUCCESS', '1')) else 1)
assert args[:2] == ['notarytool', 'submit']
assert '--no-s3-acceleration' in args and '--wait' in args
assert args[args.index('--output-format') + 1] == 'json'
if '--key' in args:
    key = pathlib.Path(args[args.index('--key') + 1])
    assert stat.S_IMODE(key.stat().st_mode) == 0o600
    assert key.read_text() == pathlib.Path(os.environ['EXPECTED_KEY']).read_text()
pathlib.Path(os.environ['CASE_DIR'], 'call.json').write_text(json.dumps(args))
mode = os.environ['NOTARY_MODE']
if mode == 'transport':
    print('connection lost', file=sys.stderr)
    sys.exit(1)
if mode == 'malformed':
    print('no JSON')
    sys.exit(0)
print(json.dumps({'status': mode.split(':')[0], 'id':
    'bad-id' if mode == 'Accepted:bad-id' else '00000000-0000-4000-8000-000000000001'}))
sys.exit(1 if mode in ('Invalid', 'Rejected', 'Accepted:nonzero') else 0)
''')
        fake.chmod(0o755)
        sleep = cls.bin / 'sleep'
        sleep.write_text('#!/bin/bash\nprintf "%s\\n" "$1" >> "$CASE_DIR/sleeps"\n')
        sleep.chmod(0o755)
        node = cls.bin / 'node'
        node.write_text('#!/bin/bash\nif [[ "${FAIL_MATERIALIZE:-0}" == 1 ]]; then exit 1; fi\n'
                        'exec "' + shutil.which('node') + '" "$@"\n')
        node.chmod(0o755)

    @classmethod
    def tearDownClass(cls):
        cls.server.terminate()
        cls.server.wait(timeout=5)
        cls.tmp.cleanup()

    def run_submit(self, name, mode='Accepted', transport='auto', profile='', key_format='normal', extra=None):
        case = self.root / name
        case.mkdir()
        pem = self.key.read_text()
        if key_format == 'escaped':
            pem = pem.replace('\n', '\\n')
        elif key_format == 'one-line':
            pem = pem.replace('\n', ' ')
        env = {'PATH': str(self.bin) + ':' + str(Path(shutil.which('node')).parent) + ':/usr/bin:/bin',
               'CASE_DIR': str(case), 'EXPECTED_KEY': str(self.key), 'NOTARY_MODE': mode,
               'PEEKABOO_NOTARY_TRANSPORT': transport, 'NOTARYTOOL_PROFILE': profile,
               'APP_STORE_CONNECT_KEY_ID': '__peekaboo_fixture__',
               'APP_STORE_CONNECT_ISSUER_ID': '__peekaboo_fixture__', 'APP_STORE_CONNECT_API_KEY_P8': pem,
               'PEEKABOO_NOTARY_FIXTURE_PROFILE': '__peekaboo_fixture__',
               'PEEKABOO_NOTARY_FIXTURE_API_BASE': self.base + '/' + name + '/notary/v2',
               'PEEKABOO_NOTARY_FIXTURE_S3_ENDPOINT': self.base + '/' + name + '/s3'}
        env.update(extra or {})
        run = subprocess.run(['/bin/bash', '-c', '''set -euo pipefail
source "$1/scripts/notary-submit.sh"
if ! result=$(peekaboo_notary_submit "$2" "$3" fixture); then exit 1; fi
printf '%s\\n' "$result"
''', 'fixture', str(ROOT), str(self.artifact), str(case)], env=env, capture_output=True, text=True)
        # All owned temporary files, including the materialized P8, must disappear on either outcome.
        self.assertEqual(list(case.glob('notary-submit.*')), [], run.stderr)
        self.assertNotIn(self.key.read_text().splitlines()[1], run.stdout + run.stderr)
        events = self.root / 'server/events.jsonl'
        rows = [json.loads(line) for line in events.read_text().splitlines()] if events.exists() else []
        return run, case, [row for row in rows if row['case'] == name]

    def test_auto_fallback_retains_bytes(self):
        run, case, events = self.run_submit('auto-fallback', mode='transport')
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(run.stdout), {'id': SUBMISSION_ID, 'status': 'Accepted'})
        self.assertIn('transport: api', run.stderr)
        self.assertTrue((case / 'call.json').exists())
        self.assertTrue(events)
        self.assertEqual((self.root / 'server/auto-fallback.uploaded').read_bytes(), self.artifact.read_bytes())
        args = json.loads((case / 'call.json').read_text())
        self.assertFalse(Path(args[args.index('--key') + 1]).exists())

    def test_direct_api(self):
        run, case, events = self.run_submit('direct', transport='api')
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertFalse((case / 'call.json').exists())
        self.assertTrue(events)

    def test_no_fallback_after_verdict_or_successful_malformed_response(self):
        for mode in ('Invalid', 'Invalid:zero', 'Rejected', 'Rejected:zero',
                     'Accepted:bad-id', 'Accepted:nonzero', 'malformed'):
            with self.subTest(mode=mode):
                run, case, events = self.run_submit('verdict-' + mode.replace(':', '-'), mode=mode)
                self.assertNotEqual(run.returncode, 0, run.stderr)
                self.assertTrue((case / 'call.json').exists())
                self.assertEqual(events, [])

    def test_forced_notarytool_does_not_fallback(self):
        run, _, events = self.run_submit('notarytool-only', mode='transport', transport='notarytool')
        self.assertNotEqual(run.returncode, 0)
        self.assertEqual(events, [])

    def test_profile_routes(self):
        run, case, events = self.run_submit('profile-api', transport='api', profile='fixture')
        self.assertNotEqual(run.returncode, 0)
        self.assertIn('keychain profile', run.stderr)
        self.assertFalse((case / 'call.json').exists())
        self.assertEqual(events, [])
        for mode in ('Accepted', 'Invalid', 'Accepted:bad-id', 'transport'):
            run, case, events = self.run_submit('profile-' + mode.replace(':', '-'), mode=mode, profile='fixture')
            self.assertEqual(run.returncode == 0, mode == 'Accepted', run.stderr)
            args = json.loads((case / 'call.json').read_text())
            self.assertIn('--keychain-profile', args)
            self.assertNotIn('--key', args)
            self.assertEqual(events, [])

    def test_key_normalization_and_success_cleanup(self):
        for key_format in ('normal', 'escaped', 'one-line'):
            run, _, events = self.run_submit('key-' + key_format, key_format=key_format)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn('transport: notarytool', run.stderr)
            self.assertEqual(events, [])

    def test_failure_cleanup(self):
        for case in ('persistent', 'invalid'):
            run, _, events = self.run_submit(case, transport='api')
            self.assertNotEqual(run.returncode, 0)
            self.assertTrue(events)
        run, case, events = self.run_submit('invalid-transport', transport='bogus')
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse((case / 'call.json').exists())
        self.assertEqual(events, [])
        run, _, events = self.run_submit('missing-key', extra={'APP_STORE_CONNECT_API_KEY_P8': ''})
        self.assertNotEqual(run.returncode, 0)
        self.assertEqual(events, [])
        run, case, events = self.run_submit('materializer-failure', extra={'FAIL_MATERIALIZE': '1'})
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse((case / 'call.json').exists())
        self.assertEqual(events, [])

    def test_no_fixture_arguments_with_invalid_synthetic_key(self):
        # Fails in local JWT signing before any network request. Exercises Bash 3.2's empty array case.
        run, case, events = self.run_submit('no-fixture', transport='api', extra={
            'PEEKABOO_NOTARY_FIXTURE_PROFILE': '', 'APP_STORE_CONNECT_API_KEY_P8': 'invalid fixture key'})
        self.assertNotEqual(run.returncode, 0)
        self.assertIn('JWT signing failed', run.stderr)
        self.assertNotIn('unbound variable', run.stderr)
        self.assertFalse((case / 'call.json').exists())
        self.assertEqual(events, [])

    def test_staple_retry_bound(self):
        for success, expected_exit, expected_waits in ((4, 0, '2\n4\n6\n'), (5, 1, '2\n4\n6\n'), (1, 0, '')):
            case = self.root / ('staple-' + str(success))
            case.mkdir()
            run = subprocess.run(['/bin/bash', '-c', 'set -euo pipefail; source "$1/scripts/notary-submit.sh"; '
                                  'peekaboo_notary_staple fixture', 'fixture', str(ROOT)],
                                 env={'PATH': str(self.bin) + ':/usr/bin:/bin', 'CASE_DIR': str(case),
                                      'STAPLE_SUCCESS': str(success)}, capture_output=True, text=True)
            self.assertEqual(run.returncode, expected_exit, run.stderr)
            self.assertEqual((case / 'staples').read_text(), str(min(success, 4)))
            sleeps = case / 'sleeps'
            self.assertEqual(sleeps.read_text() if sleeps.exists() else '', expected_waits)


if __name__ == '__main__':
    unittest.main()
