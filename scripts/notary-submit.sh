#!/usr/bin/env bash
# Shared public-release submission boundary. This file does not change caller options or traps.

peekaboo_notary_submit() (
  # A subshell owns the temporary key even when callers capture stdout or test our exit status.
  set +vx
  set -euo pipefail
  umask 077
  artifact="$1" work_dir="$2" label="$3"
  transport="${PEEKABOO_NOTARY_TRANSPORT:-auto}" profile="${NOTARYTOOL_PROFILE:-}"
  # Bash 3.2 unwinds function locals before an EXIT trap after explicit exit.
  # Assign in this isolated subshell so cleanup can still read its paths.
  key_file="" result_json="" verdict=""
  submit_exit=0 used_transport=notarytool
  fixture_args=()
  case "$transport" in
    auto|notarytool|api) ;;
    *) printf 'notary-submit: invalid transport (expected auto, notarytool, or api)\n' >&2; exit 1 ;;
  esac
  if [[ -n "$profile" && "$transport" == api ]]; then
    printf 'notary-submit: api transport requires API-key credentials, not a keychain profile\n' >&2
    exit 1
  fi
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
  attempt_dir="$(mktemp -d "$work_dir/notary-submit.XXXXXX")" || exit 1
  trap 'if [[ -n "$key_file" ]]; then /bin/rm -P "$key_file" 2>/dev/null || /bin/rm -f "$key_file"; fi; /bin/rm -rf "$attempt_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  submission="$attempt_dir/$(basename "$artifact")"
  cp "$artifact" "$submission" || exit 1
  chmod 400 "$submission" || exit 1

  if [[ -n "$profile" ]]; then
    result_json="$(xcrun notarytool submit "$submission" --keychain-profile "$profile" \
      --no-s3-acceleration --wait --output-format json)" || exit 1
  else
    for name in APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8; do
      if [[ -z "${!name:-}" ]]; then
        printf 'notary-submit: %s missing\n' "$name" >&2
        exit 1
      fi
    done
    # Endpoint overrides are only available with explicitly synthetic credential identities.
    if [[ -n "${PEEKABOO_NOTARY_FIXTURE_PROFILE:-}" ]]; then
      [[ "$PEEKABOO_NOTARY_FIXTURE_PROFILE" == __peekaboo_fixture__ &&
        "$APP_STORE_CONNECT_KEY_ID" == __peekaboo_fixture__ &&
        "$APP_STORE_CONNECT_ISSUER_ID" == __peekaboo_fixture__ ]] || exit 1
      fixture_args=(--fixture-profile __peekaboo_fixture__
        --api-base "${PEEKABOO_NOTARY_FIXTURE_API_BASE:?}"
        --s3-endpoint "${PEEKABOO_NOTARY_FIXTURE_S3_ENDPOINT:?}" --poll-interval 0.01)
    fi
    key_file="$attempt_dir/AuthKey.p8"
    APP_STORE_CONNECT_API_KEY_P8="$APP_STORE_CONNECT_API_KEY_P8" node > "$key_file" <<'NODE' || exit 1
const raw = process.env.APP_STORE_CONNECT_API_KEY_P8 ?? "";
let pem = raw.replace(/\\n/g, "\n").trim();
if (!pem.includes("\n")) {
  const match = pem.match(/^(-----BEGIN [^-]+-----)\s*(.+?)\s*(-----END [^-]+-----)$/);
  if (match) {
    const body = match[2].replace(/\s+/g, "");
    const wrapped = body.match(/.{1,64}/g)?.join("\n") ?? body;
    pem = `${match[1]}\n${wrapped}\n${match[3]}`;
  }
}
process.stdout.write(`${pem}\n`);
NODE
    chmod 600 "$key_file" || exit 1
    if [[ "$transport" != api ]]; then
      result_json="$(xcrun notarytool submit "$submission" --key "$key_file" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --no-s3-acceleration --wait --output-format json)" || submit_exit=$?
    fi
    verdict="$(printf '%s' "$result_json" | /usr/bin/plutil -extract status raw -o - - 2>/dev/null)" || verdict=""
    if [[ "$transport" == api ]] || { [[ "$transport" == auto && "$submit_exit" != 0 ]] &&
      [[ "$verdict" != Accepted && "$verdict" != Invalid && "$verdict" != Rejected ]]; }; then
      printf 'notary-submit: %s retrying retained bytes through Notary REST API\n' "$label" >&2
      used_transport=api
      result_json="$(/usr/bin/env -i /usr/bin/python3 -I "$script_dir/notary-api-submit.py" \
        --artifact "$submission" --submission-name "$(basename "$artifact")" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --key-file "$key_file" ${fixture_args[@]+"${fixture_args[@]}"})" || exit 1
    elif [[ "$submit_exit" != 0 && "$verdict" != Invalid && "$verdict" != Rejected ]]; then
      printf 'notary-submit: %s notarytool submission failed\n' "$label" >&2
      exit 1
    fi
  fi
  verdict="$(printf '%s' "$result_json" | /usr/bin/plutil -extract status raw -o - - 2>/dev/null)" || exit 1
  submission_id="$(printf '%s' "$result_json" | /usr/bin/plutil -extract id raw -o - - 2>/dev/null)" || exit 1
  if [[ "$verdict" != Accepted || ! "$submission_id" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$ ]]; then
    printf 'notary-submit: %s submission was not accepted with a UUID\n' "$label" >&2
    exit 1
  fi
  printf 'notary-submit: %s accepted: %s (transport: %s)\n' "$label" "$submission_id" "$used_transport" >&2
  printf '%s\n' "$result_json"
)

peekaboo_notary_staple() {
  local artifact="$1" attempt=1
  until xcrun stapler staple "$artifact"; do
    if [[ "$attempt" -ge 4 ]]; then
      printf 'notary-submit: stapler failed after four attempts\n' >&2
      return 1
    fi
    sleep "$((attempt * 2))" || return 1
    attempt=$((attempt + 1))
  done
}
