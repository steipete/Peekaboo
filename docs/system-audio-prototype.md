---
summary: 'System audio investigation with live persistence disabled'
read_when:
  - 'extending capture to system or process audio'
---

# System audio capture investigation

Live process/system recording is **unavailable**. The October 11 host control
demonstrated that a retained Core Audio tap persisted a source created after its
audio permission switch was observed OFF. The live tap, aggregate, IOProc and
tap-to-file implementation have therefore been removed from the executable.
No command-line flag, environment variable or host permission grant enables it.

This follows the review's fallback: keep persistence unavailable until a supported
continuing-authorization boundary exists. It does not claim to fix native
revocation behavior, implement streaming, or deliver a supported Peekaboo API.

## Current executable contract

The separate development executable accepts the previous
`<system|PID> <seconds: 0.1...60> <new-output.caf>` request syntax so callers receive
an explicit refusal rather than a false success. After argument validation, every
live request exits with status 1 and this diagnostic:

```text
Live audio persistence is disabled until continuing host authorization is verified. No tap or output was created.
```

There is no Core Audio tap or aggregate creation, no native capture callback and no
live file sink. Refusal creates neither a staging directory nor a final CAF.
Consequently retained taps and queued native callbacks cannot carry protected
samples to this executable's filesystem effect: those resources are not acquired.
A previously running older executable is not retroactively repaired by this source
change; terminate task-owned old captures before testing the matching build.

`--self-test` still exercises request validation and an AVAudioFile round-trip
using **fixed, generated fixture samples**. It creates temporary synthetic CAF
files and removes its owned fixture directory. This is not denied/revoked live
capture and cannot establish permission or audible playback.
Full/closed-pipe checks exercise actual refusal and invalid-request diagnostics.
Retired native recording deadlines and their test-only entry points are removed.

Compile and run on a Mac:

```bash
swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
  scripts/probe-system-audio.swift scripts/probe-system-audio-tests.swift \
  -o probe-system-audio
./probe-system-audio --self-test
./probe-system-audio system 1 /ABSOLUTE/NEW-OUTPUT.caf
```

The [October 12 repair receipts](evidence/system-audio-refusal-2026-10-12.json)
include matching signed-executable/source hashes, both selections under observed
ON/OFF Settings states, and GUI-launch file-absence controls. A separate generated
tone player advanced its render clock while the default output remained unchanged.
This is rendering-continuity evidence for refused requests, not physical audibility
proof for the older live recorder. No repaired mid-capture interval exists because
live acquisition is unavailable.

To reproduce that independent observation, compile
`scripts/probe-system-audio-refusal-proof.swift` with the same strict Swift flags
and run it with the repaired executable's absolute path as its single argument.
It plays a quiet generated tone, verifies refusal/file absence for both selections,
and emits redacted JSON. It never records microphone or application output.

The final recording-request command must fail without an output. It must not request broader
screen-recording or microphone permission, change playback policy, or change the
default device. Changing signing identity or allowing the test app does not enable
recording. Installed Peekaboo CLI, Bridge and MCP behavior is unchanged.

## Historical matching-build evidence

The [October 11 receipts and analysis](evidence/system-audio-consent-2026-10-11.json)
and [redacted UI transcript](evidence/system-audio-ui-2026-10-11.log) refer to the
**older live recorder**, not the current disabled entry point.
The corresponding checked-teardown source is pinned at
[de0c4b9](https://github.com/Pearcekieser/Peekaboo/blob/de0c4b9f0deca2a1e965ed8a6855ccc1825f274c/scripts/probe-system-audio.swift).

Those controls established selected 440 Hz isolation against an 880 Hz competitor,
system output capture of both tones, zero protected samples under fresh denial,
and successful checked stop/IOProc/aggregate/tap teardown before publication.
They did **not** establish continuing write authority. In the retained-tap run,
OFF was observed at harness +9.14075 seconds and a new 1320 Hz source began at
+9.18234 seconds. The new marker subsequently appeared in the final CAF.
A fresh capture under the same revoked identity contained only zeros.
Harness timestamps and CAF frame timestamps have different origins.

The marker did not exist before the OFF observation, so queued pre-revocation
audio cannot explain its later persistence. This is observed Settings-OFF behavior
on macOS 26.7, not a claim about Apple's intended effective-revocation contract.
The failed historical control is retained as evidence, not presented as a pass.
An experimental tap-property authorization round-trip did not establish a fix.
The public tap declarations inspected did not provide a supported continuing
authorization status contract; this investigation is not proof that no solution
can exist.

Independent audible playback preservation was **not** verified for that older
recorder. Successful API teardown results do not establish exhaustive failure
cleanup. The repaired executable creates no capture resources and performs no
playback mutation; that narrower behavior must be assessed separately.

## Offline analysis and future work

Recordings remain local. The committed historical exports omit private paths,
process identifiers, private bundle identifiers, credentials, IPs and endpoints.
To reanalyze an already retained local recording, convert it to PCM16 WAV with
`afconvert -f WAVE -d LEI16 INPUT.caf OUTPUT.wav`, then run
`python3 scripts/analyze-system-audio-proof.py OUTPUT.wav`.
The analyzer validates complete RIFF/PCM16 input and emits path-free expected
argument/decoding errors. One-second first-channel tone projections are finite
synthetic controls, not a universal isolation or authorization guarantee.
No file analysis operation acquires live system audio.

Re-enabling live persistence requires a supported authority boundary **before**
samples reach any staged or final file, matching-build denial and mid-capture
revocation tests, independent playback observation, and native lifecycle proof.
Private TCC APIs, permission-database edits, silence heuristics and eventual
deletion of unauthorized samples are not an acceptable substitute.

The companion [issue #1009](https://github.com/openclaw/Peekaboo/issues/1009)
continues to request selected/system capture and streaming. This contribution
retains an investigation, offline analyzer and synthetic tests only.
Human maintainer acceptance of that revised scope remains required; no approval
or merge readiness is implied by removing the unsafe recorder.
