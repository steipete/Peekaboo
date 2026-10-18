#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/terminal-artifact-env.sh
source "$ROOT_DIR/scripts/terminal-artifact-env.sh"
for secret_name in "${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do unset "$secret_name"; done
TEST_DIR="$(mktemp -d /tmp/peekaboo-terminal-notary-test.XXXXXX)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
LOG_FILE="$TEST_DIR/invocations"
CLI_TREE="$TEST_DIR/cli"
APP_ARTIFACT="$TEST_DIR/Playground.app"
CONTROLLER_TREE="$TEST_DIR/qualification"

fail() {
  printf 'test-notarize-terminal-artifact: %s\n' "$*" >&2
  exit 1
}

notary_entry_prefix="$(awk '/^raw_function_names_file=/{exit} {print}' \
  "$ROOT_DIR/scripts/notarize-terminal-artifact.sh")"
for secret_name in \
  APP_STORE_CONNECT_API_KEY_P8 APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID \
  ASC_PRIVATE_KEY_P8 ASC_KEY_ID ASC_ISSUER_ID CODESIGN_KEYCHAIN DYLD_INSERT_LIBRARIES \
  DYLD_LIBRARY_PATH GH_TOKEN GITHUB_TOKEN MAC_RELEASE_CODESIGN_KEYCHAIN \
  MAC_RELEASE_CODESIGN_KEYCHAIN_PASSWORD MAC_RELEASE_SPARKLE_KEY_FILE \
  MAC_RELEASE_SPARKLE_OP_REF MOLTY_OP_SERVICE_ACCOUNT_TOKEN NODE_AUTH_TOKEN NODE_OPTIONS \
  NODE_PATH NOTARYTOOL_KEY NOTARYTOOL_KEY_ID NOTARYTOOL_ISSUER NPM_CONFIG_USERCONFIG NPM_TOKEN \
  OP_SERVICE_ACCOUNT_TOKEN SIGN_IDENTITY SPARKLE_PRIVATE_KEY SPARKLE_PRIVATE_KEY_FILE; do
  grep -Fwq "$secret_name" <<< "$notary_entry_prefix" || \
    fail "notary entrypoint does not de-export $secret_name before its environment scan"
done

# Production leaves fixture_api_args empty; /bin/bash 3.2 with nounset rejects an unguarded empty-array expansion.
if grep -n '"${fixture_api_args\[@\]}"' "$ROOT_DIR/scripts/notarize-terminal-artifact.sh" | \
  grep -v '${fixture_api_args\[@\]+' >/dev/null; then
  fail 'fixture_api_args expansion must be guarded for Bash 3.2 nounset'
fi
/bin/bash -c 'set -u; fixture_api_args=(); printf "%s" ${fixture_api_args[@]+"${fixture_api_args[@]}"}' || \
  fail 'guarded empty fixture_api_args expansion fails under /bin/bash nounset'

mkdir -p "$CLI_TREE"
printf 'int main(void) { return 0; }\n' > "$TEST_DIR/main.c"
/usr/bin/clang -arch arm64 "$TEST_DIR/main.c" -o "$TEST_DIR/cli-arm64"
/usr/bin/clang -arch x86_64 "$TEST_DIR/main.c" -o "$TEST_DIR/cli-x86_64"
/usr/bin/lipo -create "$TEST_DIR/cli-arm64" "$TEST_DIR/cli-x86_64" -output "$CLI_TREE/peekaboo"
mkdir -p "$APP_ARTIFACT/Contents/MacOS"
cp "$CLI_TREE/peekaboo" "$APP_ARTIFACT/Contents/MacOS/Playground"
cat > "$APP_ARTIFACT/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>Playground</string></dict></plist>
EOF
mkdir -p "$CONTROLLER_TREE"
cp "$CLI_TREE/peekaboo" "$CONTROLLER_TREE/peekaboo-certification-controller"
cp "$CLI_TREE/peekaboo" "$CONTROLLER_TREE/background-computer-use-probe"
cp /usr/bin/true "$CONTROLLER_TREE/libswiftCompatibilityFixture.dylib"

cat > "$TEST_DIR/ditto" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'ditto %s\n' "$*" >> "${LOG_FILE:?}"
if [[ "${1:-}" == -c ]]; then
  # Match the fake xattr world only when archiving; copies must retain arbitrary attrs.
  archive_args=()
  for argument in "$@"; do
    [[ "$argument" == --sequesterRsrc ]] || archive_args+=("$argument")
  done
  /usr/bin/ditto --norsrc --noextattr "${archive_args[@]}"
  if [[ "${TERMINAL_DITTO_APPLEDOUBLE:-0}" == 1 ]]; then
    payload="$(dirname "${!#}")/appledouble"
    mkdir -p "$payload/__MACOSX"
    printf 'fixture\n' > "$payload/__MACOSX/._fixture"
    (cd "$payload" && /usr/bin/zip -q "${!#}" __MACOSX/._fixture)
  fi
  exit 0
fi
exec /usr/bin/ditto "$@"
EOF
cat > "$TEST_DIR/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcrun %s\n' "$*" >> "${LOG_FILE:?}"
case "${1:-}:${2:-}" in
  notarytool:history) [[ -z "${TERMINAL_NOTARY_HISTORY_FAIL:-}" ]] || exit 92; printf '{}\n' ;;
  notarytool:submit)
    case "${TERMINAL_NOTARY_MODE:-accepted}" in
      accepted) printf '{"id":"00000000-0000-4000-8000-000000000001","status":"Accepted"}\n' ;;
      rejected) printf '{"id":"00000000-0000-4000-8000-000000000001","status":"Invalid"}\n' ;;
      malformed) printf 'not-json\n' ;;
      invalid-exit) printf '{"id":"00000000-0000-4000-8000-000000000001","status":"Invalid"}\n'; exit 1 ;;
      accepted-exit) printf '{"id":"00000000-0000-4000-8000-000000000001","status":"Accepted"}\n'; exit 1 ;;
      *) exit 91 ;;
    esac
    ;;
  stapler:*)
    if [[ "${2:-}" == staple && "${TERMINAL_STAPLER_FAIL:-0}" == once && ! -f "$LOG_FILE.stapled" ]]; then
      touch "$LOG_FILE.stapled"
      exit 1
    fi
    [[ "${TERMINAL_STAPLER_FAIL:-0}" != 1 ]]
    ;;
esac
EOF
cat > "$TEST_DIR/codesign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'codesign %s\n' "$*" >> "${LOG_FILE:?}"
if [[ "${1:-}" == -dvvv ]]; then
  target="${!#}"
  identifier="${TERMINAL_CODE_IDENTIFIER:-boo.peekaboo.peekaboo}"
  case "$(basename "$target")" in
    background-computer-use-probe) identifier=boo.peekaboo.background-computer-use-probe ;;
    libswiftCompatibility*.dylib) identifier=com.apple.dt.runtime.swiftCompatibilityFixture ;;
  esac
  cat <<DETAILS
Identifier=$identifier
CDHash=0123456789abcdef0123456789abcdef01234567
Authority=Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
TeamIdentifier=FWJYW4S8P8
DETAILS
  for counter in $(seq 1 5000); do printf 'Trailing=%s\n' "$counter"; done
  exit 0
fi
[[ "${TERMINAL_CODESIGN_FAIL_VERIFY:-0}" != 1 ]]
EOF
cat > "$TEST_DIR/xattr" <<'EOF'
#!/usr/bin/ruby
require 'find'
require 'open3'

exec('/usr/bin/xattr', *ARGV) unless ARGV.length == 2 && ARGV.first == '-r'

def inspect_xattrs(*args)
  output, errors, result = Open3.capture3('/usr/bin/xattr', *args)
  STDERR.write(errors)
  exit(result.exitstatus || 1) unless result.success?
  output
end

# Fake-provider fixtures ignore only the host's persistent 11-byte provenance marker;
# this is not native zero-metadata proof. Never inspect metadata outside this fixture.
fixture_root = File.realpath(__dir__)
within_fixture = lambda do |path|
  resolved = File.realpath(path)
  abort('fixture xattr: path outside fixture') unless resolved == fixture_root ||
    resolved.start_with?("#{fixture_root}/")
  resolved
end
target = within_fixture.call(ARGV.last)
Find.find(target, ignore_error: false) do |entry|
  resolved = within_fixture.call(entry)
  inspect_xattrs(resolved).each_line do |line|
    name = line.chomp
    if name == 'com.apple.provenance'
      listing, errors, result = Open3.capture3({ 'LC_ALL' => 'C' }, '/bin/ls', '-ld@', resolved)
      abort('fixture xattr: size inspection failed') unless result.success? && errors.empty?
      sizes = listing.lines.map(&:split).select { |fields| fields.first == name }.map { |fields| fields[1] }
      next if sizes == ['11']
    end
    puts "#{entry}: #{name}"
  end
end
EOF
chmod 755 "$TEST_DIR/ditto" "$TEST_DIR/xcrun" "$TEST_DIR/codesign" "$TEST_DIR/xattr"
export LOG_FILE

ln -s "$ROOT_DIR/scripts/test-notarize-terminal-artifact.sh" "$TEST_DIR/xattr-outside"
for xattr_target in "$TEST_DIR/missing" "$ROOT_DIR/scripts/test-notarize-terminal-artifact.sh" \
  "$TEST_DIR/xattr-outside"; do
  if "$TEST_DIR/xattr" -r "$xattr_target" >"$TEST_DIR/xattr-error.log" 2>&1; then
    fail 'fixture xattr masked an inspection failure or accepted an outside path'
  fi
done
rm "$TEST_DIR/xattr-outside"

run_notary() {
  PEEKABOO_TERMINAL_TEST_MODE=1 \
    TERMINAL_NOTARY_XCRUN_BIN="$TEST_DIR/xcrun" \
    TERMINAL_NOTARY_DITTO_BIN="$TEST_DIR/ditto" \
    TERMINAL_NOTARY_CODESIGN_BIN="$TEST_DIR/codesign" \
    TERMINAL_NOTARY_XATTR_BIN="$TEST_DIR/xattr" \
    TERMINAL_NOTARY_UNZIP_BIN=/usr/bin/unzip \
    /bin/bash --noprofile --norc -p "$ROOT_DIR/scripts/notarize-terminal-artifact.sh" "$@"
}

profile_transaction="$TEST_DIR/profile-transaction"
run_notary --kind cli-tree --artifact "$CLI_TREE" --transaction "$profile_transaction" \
  --notary-profile __peekaboo_fixture__ >/dev/null
jq -e '
  .version == 2 and .kind == "cli_tree" and .status == "Accepted" and
  .submission.path == ("notary/submissions/" + .submission.sha256) and
  .submission.size > 0 and (.submission.sha256 | test("^[0-9a-f]{64}$")) and
  .code_identity.authority == "Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)" and
  .code_identity.identifier == "boo.peekaboo.peekaboo" and .code_identity.team_id == "FWJYW4S8P8" and
  .code_identity.cdhash == "0123456789abcdef0123456789abcdef01234567" and
  (.code_identity.architectures | sort) == ["arm64", "x86_64"] and
  (.code_identity.cdhashes | keys | sort) == ["arm64", "x86_64"] and
  .final_artifact.tree_manifest_size > 0 and
  (.final_artifact.tree_manifest_sha256 | test("^[0-9a-f]{64}$"))
' "$profile_transaction/receipt.json" >/dev/null || fail 'profile receipt schema is incomplete'
[[ -f "$profile_transaction/submission.bin" ]]
history_line="$(grep -n 'xcrun notarytool history --keychain-profile __peekaboo_fixture__' "$LOG_FILE" | cut -d: -f1)"
submit_line="$(grep -n 'xcrun notarytool submit .*--keychain-profile __peekaboo_fixture__ --no-s3-acceleration --wait --output-format json' \
  "$LOG_FILE" | cut -d: -f1)"
[[ -n "$history_line" && -n "$submit_line" && "$history_line" -lt "$submit_line" ]] || \
  fail 'profile history did not precede the exact submit command'

profile_reexec_transaction="$TEST_DIR/profile-reexec-transaction"
if (
  # Exported deliberately to test the child environment boundary, not called here.
  # shellcheck disable=SC2329
  hostile_notary_function() { return 97; }
  export -f hostile_notary_function
  export OP_SERVICE_ACCOUNT_TOKEN=unrelated-credential
  run_notary --kind cli-tree --artifact "$CLI_TREE" \
    --transaction "$profile_reexec_transaction" \
    --notary-profile __peekaboo_fixture__ >/dev/null 2>&1
); then
  fail 'credential-bearing notary accepted an exported-function environment'
fi
[[ ! -e "$profile_reexec_transaction" ]] || \
  fail 'function-environment refusal published a notary transaction'

assert_cli_failure() {
  local label="$1"
  local mode="$2"
  local verify_fail="$3"
  local expected_error="$4"
  local transaction="$TEST_DIR/$label-transaction"
  if TERMINAL_NOTARY_MODE="$mode" TERMINAL_CODESIGN_FAIL_VERIFY="$verify_fail" \
    run_notary --kind cli-tree --artifact "$CLI_TREE" --transaction "$transaction" \
      --notary-profile __peekaboo_fixture__ >"$TEST_DIR/$label.log" 2>&1; then
    fail "$label unexpectedly succeeded"
  fi
  grep -Fq "$expected_error" "$TEST_DIR/$label.log" || fail "$label failed for an unexpected reason"
  [[ ! -e "$transaction" ]] || fail "$label published a partial transaction"
}

assert_cli_failure rejected rejected 0 'notary submission was not accepted'
assert_cli_failure malformed malformed 0 'notary response is malformed'
assert_cli_failure signature-verify accepted 1 'CLI tree pre-submit identity mismatch'
appledouble_transaction="$TEST_DIR/appledouble-transaction"
if TERMINAL_DITTO_APPLEDOUBLE=1 run_notary --kind cli-tree --artifact "$CLI_TREE" \
  --transaction "$appledouble_transaction" --notary-profile __peekaboo_fixture__ \
  >"$TEST_DIR/appledouble.log" 2>&1; then
  fail 'AppleDouble submission unexpectedly succeeded'
fi
grep -Fq 'notary submission contains AppleDouble payload' "$TEST_DIR/appledouble.log" || \
  fail 'AppleDouble submission failed for an unexpected reason'
[[ ! -e "$appledouble_transaction" ]] || fail 'AppleDouble submission published a transaction'
staple_transaction="$TEST_DIR/staple-transaction"
if TERMINAL_CODE_IDENTIFIER=boo.peekaboo.playground.debug TERMINAL_STAPLER_FAIL=1 \
  run_notary --kind app --artifact "$APP_ARTIFACT" --transaction "$staple_transaction" \
    --notary-profile __peekaboo_fixture__ >/dev/null 2>&1; then
  fail 'staple failure unexpectedly succeeded'
fi
[[ ! -e "$staple_transaction" ]] || fail 'staple failure published a partial transaction'

live_fixture_transaction="$TEST_DIR/live-fixture-transaction"
if APP_STORE_CONNECT_API_KEY_P8=secret run_notary --kind cli-tree --artifact "$CLI_TREE" \
  --transaction "$live_fixture_transaction" --notary-profile __peekaboo_fixture__ >/dev/null 2>&1; then
  fail 'fixture tools accepted a live credential variable'
fi
[[ ! -e "$live_fixture_transaction" ]]

xattr_cli="$TEST_DIR/xattr-cli"
/usr/bin/ditto "$CLI_TREE" "$xattr_cli"
/usr/bin/xattr -w com.openclaw.peekaboo.fixture fixturedata "$xattr_cli/peekaboo"
"$TEST_DIR/xattr" -r "$xattr_cli" > "$TEST_DIR/xattr-names"
grep -Fq ': com.openclaw.peekaboo.fixture' "$TEST_DIR/xattr-names" || \
  fail 'fixture xattr masked an arbitrary attribute'
xattr_transaction="$TEST_DIR/xattr-transaction"
if run_notary --kind cli-tree --artifact "$xattr_cli" --transaction "$xattr_transaction" \
  --notary-profile __peekaboo_fixture__ >"$TEST_DIR/xattr-notary.log" 2>&1; then
  fail 'xattr-bearing artifact unexpectedly succeeded'
fi
grep -Fq 'artifact contains unbound extended attributes' "$TEST_DIR/xattr-notary.log" || \
  fail 'xattr-bearing artifact failed for an unexpected reason'
[[ ! -e "$xattr_transaction" ]]

app_transaction="$TEST_DIR/app-transaction"
TERMINAL_CODE_IDENTIFIER=boo.peekaboo.playground.debug \
  run_notary --kind app --artifact "$APP_ARTIFACT" --transaction "$app_transaction" \
    --notary-profile __peekaboo_fixture__ >/dev/null
tree_sha="$(/usr/bin/shasum -a 256 "$app_transaction/tree.json" | /usr/bin/awk '{print $1}')"
jq -e --arg treeSHA "$tree_sha" --argjson treeSize "$(/usr/bin/stat -f%z "$app_transaction/tree.json")" '
  .final_artifact == {tree_manifest_sha256: $treeSHA, tree_manifest_size: $treeSize}
' "$app_transaction/receipt.json" >/dev/null || fail 'app receipt does not bind its atomic post-staple tree'
[[ -d "$app_transaction/Playground.app" ]]

controller_transaction="$TEST_DIR/controller-transaction"
symlink_tree="$TEST_DIR/symlink-qualification"
/usr/bin/ditto "$CONTROLLER_TREE" "$symlink_tree"
ln -s /usr/bin/true "$symlink_tree/foreign-helper"
if TERMINAL_CODE_IDENTIFIER=boo.peekaboo.peekaboo-certification-controller \
  run_notary --kind controller-tree --artifact "$symlink_tree" \
    --transaction "$TEST_DIR/symlink-controller-transaction" \
    --notary-profile __peekaboo_fixture__ >/dev/null 2>&1; then
  fail 'controller tree accepted a symlink helper'
fi
[[ ! -e "$TEST_DIR/symlink-controller-transaction" ]]

TERMINAL_CODE_IDENTIFIER=boo.peekaboo.peekaboo-certification-controller \
  run_notary --kind controller-tree --artifact "$CONTROLLER_TREE" --transaction "$controller_transaction" \
    --notary-profile __peekaboo_fixture__ >/dev/null
controller_tree_sha="$(/usr/bin/shasum -a 256 "$controller_transaction/tree.json" | /usr/bin/awk '{print $1}')"
jq -e --arg sha "$controller_tree_sha" '
  .kind == "controller_tree" and .final_artifact.tree_manifest_sha256 == $sha
' "$controller_transaction/receipt.json" >/dev/null || fail 'controller tree receipt is incomplete'

if TERMINAL_NOTARY_XCRUN_BIN="$TEST_DIR/xcrun" \
  "$ROOT_DIR/scripts/notarize-terminal-artifact.sh" --kind cli-tree --artifact "$CLI_TREE" \
  --transaction "$TEST_DIR/override-transaction" --notary-profile __peekaboo_fixture__ >/dev/null 2>&1; then
  fail 'production accepted a test tool override'
fi

# API fixtures use only a freshly generated key; live credential variables remain forbidden.
/usr/bin/openssl ecparam -name prime256v1 -genkey -noout -out "$TEST_DIR/throwaway.p8"
/usr/bin/python3 -I "$ROOT_DIR/scripts/fixtures/notary-api-server.py" "$TEST_DIR/server" \
  >"$TEST_DIR/server.log" 2>&1 &
server_pid=$!
for ((attempt = 1; attempt <= 100; attempt++)); do
  [[ ! -f "$TEST_DIR/server/port" ]] || break
  kill -0 "$server_pid" 2>/dev/null || fail 'fixture server stopped'
  sleep 0.05
done
[[ -f "$TEST_DIR/server/port" ]] || fail 'fixture server did not start'
server_base="http://127.0.0.1:$(cat "$TEST_DIR/server/port")"
# Use several real S3-sized parts to prove parallel requests and exact retained bytes.
/usr/bin/python3 -I - "$TEST_DIR/upload.dmg" <<'PYDATA'
import os
import sys
with open(sys.argv[1], 'wb') as output:
    output.write(os.urandom(17 * 1024 * 1024 + 7))
PYDATA

run_api_fixture() {
  local fixture_case="$1"
  shift
  TERMINAL_NOTARY_API_KEY_FILE="$TEST_DIR/throwaway.p8" \
    TERMINAL_NOTARY_API_BASE_URL="$server_base/$fixture_case/notary/v2" \
    TERMINAL_NOTARY_S3_ENDPOINT="$server_base/$fixture_case/s3" \
    run_notary "$@" --notary-profile __peekaboo_fixture__
}

TERMINAL_NOTARY_MODE=transport-failure run_api_fixture auto-fallback \
  --kind dmg --artifact "$TEST_DIR/upload.dmg" --transaction "$TEST_DIR/auto-fallback" \
  >"$TEST_DIR/auto-fallback.log" 2>&1 || { cat "$TEST_DIR/auto-fallback.log"; fail 'auto fallback failed'; }
jq -e '.submission.transport == "api" and .status == "Accepted"' \
  "$TEST_DIR/auto-fallback/receipt.json" >/dev/null
cmp "$TEST_DIR/upload.dmg" "$TEST_DIR/auto-fallback/submission.bin"
cmp "$TEST_DIR/server/auto-fallback.uploaded" "$TEST_DIR/auto-fallback/submission.bin"
jq -e '.peak > 1' "$TEST_DIR/server/auto-fallback.stats" >/dev/null || fail 'upload was not parallel'
grep -Fq 'stapler staple' "$LOG_FILE" || fail 'REST path did not staple'

# A failed history preflight is a transport failure: auto falls back, notarytool mode refuses.
cp "$LOG_FILE" "$TEST_DIR/before-history.log"
TERMINAL_NOTARY_HISTORY_FAIL=1 run_api_fixture history-fallback \
  --kind dmg --artifact "$TEST_DIR/upload.dmg" --transaction "$TEST_DIR/history-fallback" \
  >"$TEST_DIR/history-fallback.log" 2>&1 || { cat "$TEST_DIR/history-fallback.log"; fail 'history fallback failed'; }
jq -e '.submission.transport == "api"' "$TEST_DIR/history-fallback/receipt.json" >/dev/null
[[ "$(grep -c 'notarytool submit' "$LOG_FILE")" == "$(grep -c 'notarytool submit' "$TEST_DIR/before-history.log")" ]] || \
  fail 'submit ran after a failed history preflight'
if TERMINAL_NOTARY_HISTORY_FAIL=1 run_api_fixture history-refused --kind dmg --artifact "$TEST_DIR/upload.dmg" \
  --transaction "$TEST_DIR/history-refused" --notary-transport notarytool >"$TEST_DIR/history-refused.log" 2>&1; then
  fail 'notarytool transport ignored a failed history preflight'
fi
! grep -Fq '"case": "history-refused"' "$TEST_DIR/server/events.jsonl" || fail 'notarytool transport contacted REST'

# Explicit API must skip both history and submit, and tolerate ticket propagation lag.
cp "$LOG_FILE" "$TEST_DIR/before-api.log"
TERMINAL_NOTARY_MODE=transport-failure TERMINAL_STAPLER_FAIL=once \
  TERMINAL_CODE_IDENTIFIER=boo.peekaboo.playground.debug run_api_fixture direct \
  --kind app --artifact "$APP_ARTIFACT" --transaction "$TEST_DIR/direct" --notary-transport api \
  >"$TEST_DIR/direct.log" 2>&1 || { cat "$TEST_DIR/direct.log"; fail 'direct API failed'; }
[[ -f "$LOG_FILE.stapled" ]] || fail 'stapler retry was not exercised'
[[ "$(grep -c 'notarytool' "$LOG_FILE")" == "$(grep -c 'notarytool' "$TEST_DIR/before-api.log")" ]] || \
  fail 'explicit API invoked notarytool'
jq -e '.submission.transport == "api"' "$TEST_DIR/direct/receipt.json" >/dev/null

for refused_case in invalid-exit rejected transport-only accepted-exit; do
  mode="$refused_case"
  transport=auto
  if [[ "$refused_case" == transport-only ]]; then mode='transport-failure'; transport=notarytool; fi
  if TERMINAL_NOTARY_MODE="$mode" run_api_fixture "$refused_case" --kind dmg \
    --artifact "$TEST_DIR/upload.dmg" --transaction "$TEST_DIR/$refused_case" \
    --notary-transport "$transport" >"$TEST_DIR/$refused_case.log" 2>&1; then
    fail "$refused_case unexpectedly succeeded"
  fi
  [[ ! -e "$TEST_DIR/$refused_case" ]] || fail "$refused_case published a receipt"
  if grep -Fq "\"case\": \"$refused_case\"" "$TEST_DIR/server/events.jsonl"; then
    fail "$refused_case unexpectedly contacted REST"
  fi
done

for api_case in transient invalid persistent bad-etag bad-final-etag complete-error complete-error-persistent; do
  transaction="$TEST_DIR/api-$api_case"
  if run_api_fixture "$api_case" --kind dmg --artifact "$TEST_DIR/upload.dmg" \
    --transaction "$transaction" --notary-transport api >"$TEST_DIR/api-$api_case.log" 2>&1; then
    case "$api_case" in
      transient) jq -e '.tries["1"] == 2 and .peak > 1' "$TEST_DIR/server/transient.stats" >/dev/null ;;
      complete-error)
        # The embedded InternalError is retried once instead of aborting the uploaded parts.
        [[ "$(jq -sr '[.[] | select(.case == "complete-error" and .method == "POST" and (.query | has("uploadId")))] | length' \
          "$TEST_DIR/server/events.jsonl")" == 2 ]] || fail 'completion was not retried exactly once'
        ! jq -se 'any(.[]; .case == "complete-error" and .method == "DELETE")' "$TEST_DIR/server/events.jsonl" \
          >/dev/null || fail 'retried completion aborted the upload' ;;
      *) fail "$api_case unexpectedly succeeded" ;;
    esac
  else
    [[ "$api_case" != transient && "$api_case" != complete-error ]] || \
      { cat "$TEST_DIR/api-$api_case.log"; fail "$api_case retry failed"; }
    [[ ! -e "$transaction" ]] || fail "$api_case published a receipt"
    if [[ "$api_case" == invalid ]]; then
      grep -Fq 'developer log logs.example.test/developer/log.json' "$TEST_DIR/api-invalid.log" || \
        fail 'missing sanitized developer log URL'
    else
      /usr/bin/python3 -I - "$TEST_DIR/server/events.jsonl" "$api_case" <<'PYCHECK'
import json
import sys
rows = [json.loads(line) for line in open(sys.argv[1])]
aborted = any(row['case'] == sys.argv[2] and row['method'] == 'DELETE' for row in rows)
# A completed upload cannot be aborted; every earlier failure must abort it.
assert aborted == (sys.argv[2] != 'bad-final-etag'), 'wrong multipart abort behavior'
assert not any(row['method'] == 'HEAD' for row in rows), 'upload must not read the object back'
if sys.argv[2] in ('persistent', 'bad-etag'):
    from collections import Counter
    attempts = Counter(row['query']['partNumber'][0] for row in rows
                       if row['case'] == sys.argv[2] and row['method'] == 'PUT')
    if sys.argv[2] == 'persistent':
        assert attempts['1'] == 4, 'wrong retry bound'
    else:
        # Any exhausted worker cancels its peers; part 1 need not finish first.
        assert attempts and max(attempts.values()) == 4, 'wrong retry bound'
PYCHECK
    fi
  fi
  if grep -Eq 'DO_NOT_PRINT|FIXTURESECRET|FIXTURESESSION|Bearer |AWS4-HMAC' "$TEST_DIR/api-$api_case.log"; then
    fail "$api_case leaked authentication or remote response material"
  fi
done

for override_name in TERMINAL_NOTARY_API_KEY_FILE TERMINAL_NOTARY_API_BASE_URL TERMINAL_NOTARY_S3_ENDPOINT; do
  if /usr/bin/env "$override_name=fixture" /bin/bash -p "$ROOT_DIR/scripts/notarize-terminal-artifact.sh" \
    --kind dmg --artifact "$TEST_DIR/upload.dmg" --transaction "$TEST_DIR/forbidden-$override_name" \
    >"$TEST_DIR/override.log" 2>&1; then
    fail "production accepted $override_name"
  fi
  grep -Fq "$override_name is test-only" "$TEST_DIR/override.log" || fail 'override failed for wrong reason'
done

printf 'test-notarize-terminal-artifact: ok (fake signing/notary and metadata tools; no native zero-metadata proof)\n'
