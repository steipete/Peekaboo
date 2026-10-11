---
summary: 'System and process audio capture investigation and isolated feasibility probe'
read_when:
  - 'extending capture to system or process audio'
---

# System audio capture prototype

**Merge blocker:** the October 11 revocation control below demonstrates that an
existing tap continued to persist a protected marker after its host's audio
permission switch was turned off. This experimental probe is not a safe supported
capture interface. Do not merge or integrate it while that boundary is unresolved.

Investigated 2026-10-09 against `openclaw/Peekaboo` commit
`c02c26927d77ddcc17a61233cd4bc0cf83de485a`.
This is an isolated development probe, not a released Peekaboo command or MCP tool.

## Existing implementation

`Core/PeekabooCore/Sources/PeekabooAutomation/Services/Audio/AudioInputService.swift`
records microphone input through TachikomaAudio and can transcribe it through an AI
provider. It does not record another process's output. The screen capture operator
explicitly sets `capturesAudio = false`.

The prototype uses Core Audio process taps, which can target non-GUI processes such
as Xcode's `SimAudioProcessorService`. It can also explicitly select a global stereo
mix. It does not capture a microphone, invoke transcription, transmit recordings,
mute playback, or change the default output device.
The aggregate uses the current output device for its clock. Duplex outputs such
as headsets and audio interfaces are refused before acquisition: their physical
input streams must not be mistaken for tap audio. Output-only devices are required.

Apple references:

- [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)

## Related upstream work

GitHub searches included open and closed issues and PRs for `audio`, `system audio`,
`audio capture`, `audio recording`, `process tap`, and adjacent sound/recording issues.
No direct raw-system-audio feature request or implementation PR was identified.
Relevant adjacent history:

- [Issue #75](https://github.com/openclaw/Peekaboo/issues/75): permission attribution differs under Node.
- [PR #204](https://github.com/openclaw/Peekaboo/pull/204): speech recorder cancellation/lifecycle fix; merged.
- [Issue #169](https://github.com/openclaw/Peekaboo/issues/169): bounded live/video capture via MCP; closed.
- [Issue #170](https://github.com/openclaw/Peekaboo/issues/170): opaque Bridge capture errors; closed.
- [Issue #171](https://github.com/openclaw/Peekaboo/issues/171): action-wrapped video capture; closed.

## Contribution requirements

The checkout has a root `AGENTS.md`; no dedicated CONTRIBUTING document or PR
template was found. Its requirements include Swift 6.2, explicit `self`, four-space
indentation, 120-column wrapping, existing module boundaries, regression tests,
Conventional Commits, and a PR description with validation and behavior evidence.
Before handoff it calls for lint, formatting checks, and `pnpm run test:safe`.
Before landing it requires autoreview and green CI. Submodule changes belong in
their own upstream repositories. None are needed for this prototype.

## Reproduce the prototype

Compile the two Swift source files together on a Mac:

```bash
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors \
  -parse-as-library scripts/probe-system-audio.swift scripts/probe-system-audio-tests.swift \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
  -Xlinker scripts/probe-system-audio.plist -o /your/task-directory/probe-system-audio
/your/task-directory/probe-system-audio --self-test
/your/task-directory/probe-system-audio 12345 5 /your/task-directory/process.caf
# Global output is explicit:
/your/task-directory/probe-system-audio system 5 /your/task-directory/system.caf
```

Output is lossless CAF with JSON containing frame/sample counts, sample rate,
channels, peak, RMS, and nonzero sample count. Durations are bounded to 0.1–60 seconds.
Existing output files are refused. Zero frames fail; zero-valued frames produce an
explicit warning, because they cannot distinguish actual silence from denied capture.
The private aggregate and tap are destroyed when recording ends or the async wait
throws. Native HAL calls can also block. A process deadline of requested duration
plus ten seconds terminates a stalled standalone probe with exit code 2. This
process-level containment must never be copied into the GUI Bridge itself.
Forced deadline exit bypasses Swift cleanup: it may leave a private (mode 0700)
`.peekaboo-audio-*` directory beside the requested output containing an incomplete
CAF. This file is not published as a result. Inspect/remove those owned partials
after a failed test; the probe does not claim confirmed native cleanup on a stall.
A native destruction stall can leave a closed staged CAF without a success receipt.
Checked native teardown now precedes publication of the requested final CAF.
The output path alone does not establish successful operation or exhaustive cleanup.

## Evidence and limits

Test host: macOS 26.7, Apple Silicon, Xcode Swift 6.4.

- Strict-concurrency compilation with warnings treated as errors: passed.
- Nine invalid-request cases: passed without accessing Core Audio.
- PID/system selection, PCM sample counts, peak/RMS, readable CAF, existing-output
  protection, and silent PCM handling: passed using injected stereo PCM.
- Live simulator-service capture: stalled; no live samples verified.
- The first SSH launch was attributed to `com.apple.sshd-keygen-wrapper` in TCC logs.
- Launching the named app from the external volume failed with Launch Services -10810.
- A small app copy in the user's Applications directory launched successfully.
  TCC attributed the audio request to the separate test prototype's bundle identity.
  A small local output path avoids an additional removable-volume access prompt.
- TCC preflight reported unknown audio authorization. A system-audio prompt was
  not verified. A native stack sample established that the process was blocked
  inside `AudioDeviceStop_mac_imp` / `HALC_ShellDevice::StopIOProc`, rather than
  establishing that a permission dialog was pending. The stalled process was stopped.
- After adding the deadline, strict compilation and PCM self-tests passed again.
  The SSH live-test connection ended with status 255, without a verified CAF or
  timeout message. A subsequent process check confirmed no recorder remained.
  This does not establish that the watchdog's intended exit code 2 was observed.

These checks do not establish actual audible capture, cross-process isolation,
live cancellation/resource cleanup, or production readiness. The initial investigation
did not run full workspace tests, SwiftLint, or SwiftFormat. Changed-file PR checks
are reported separately and do not establish full workspace readiness.
Installed Peekaboo remains unchanged.

## Integration after feasibility

### Follow-up live validation (2026-10-10)

The installed, Developer ID-signed Peekaboo GUI Bridge was used to operate System
Settings. It was not modified or re-signed. The separate ad-hoc-signed prototype
was added to **System Audio Recording Only**, and its switch was verified enabled.
After the recorder changed, only its own grant was toggled off/on and rechecked.
TCC logs attributed requests to the prototype identity. The enabled UI switch is
not proof of successful native authorization or acquisition.

The first real scheduled watchdog fired with `SIGTRAP`: its closure inherited
main-actor isolation but ran on a global queue. The crash stack included
`_dispatch_assert_queue_fail` and `closure #1 in static SystemAudioProbe.main()`.
The watchdog now uses an explicitly `@Sendable` work item. Regression subprocesses
schedule that same work-item factory on a global queue and verify exit status 2
with both full and closed stderr pipes; those checks pass alongside the PCM tests.

Two synthetic tone processes (440 Hz and 880 Hz) were launched together. Selected
process capture, a retry after refreshing the grant, and explicit system capture
each produced no final CAF or success receipt. The corrected GUI-launched recorder
emitted its deadline diagnostic and ended in approximately 13.7 seconds for a
three-second request plus ten-second deadline allowance. LaunchServices returned
0, which is **not** the recorder's exit status. No recorder or test player remained
after the runs; this does not prove native aggregate/tap cleanup.

A one-second native sample of the system control showed acquisition blocked in
`AudioDeviceCreateIOProcIDWithBlock`, through
`HALC_ProxyIOContext::_TellServerAboutStreamUsage` and
`HALC_ProxyObject::SetPropertyData`, waiting on Mach IPC. The active output was the
built-in speakers at 48 kHz. Private partials were retained for investigation.
Known-signal acquisition, process isolation, playback preservation, and native
cleanup therefore remain unverified. This stack does not establish a permission
dialog or a macOS defect as the cause.

### Consent-cleared live validation (2026-10-11)

Further investigation found the user TCC service waiting in
`CFUserNotificationReceiveResponse`. A pending system-audio consent dialog for
the prototype was hosted by UserNotificationCenter at a nonstandard window layer:
the ordinary window inventory omitted it, but exact-window observation exposed
its text and Allow button. Two queued prototype dialogs were approved through
the trusted Peekaboo Bridge, with fresh observations between actions.

A temporary tap-only aggregate experiment then captured both selected-process and
system output. The original implementation was restored and rebuilt; its executable
SHA-256 matched the previously tested build
`c7bad5a9c5ed7cc3d210be159531cd10761bd8d0ca2908bf97ad82aaf214d5ea`.
Restoring the ad-hoc signature triggered another prototype consent dialog, which
was observed and approved. Both original-implementation controls then completed
with final CAF files, success receipts, empty stderr, and no staging directories.
The aggregate experiment was reverted; no capture-code change is needed for these
successful controls. The installed Peekaboo app remained unchanged.

| Original implementation control | Elapsed | Frames at 48 kHz | Signal check |
| --- | --- | --- | --- |
| Selected 440 Hz process, simultaneous 880 Hz process | 3.32 s | 151,552 | 440 Hz present; 880 Hz below -60 dB relative to 440 Hz |
| Explicit system output, both processes | 3.22 s | 148,992 | Both tones present at approximately equal amplitude |

Signal analysis converted the local CAF to 16-bit WAV, selected its first channel,
and projected a 1.5-second interior interval onto sine/cosine pairs at 440 and
880 Hz. The selected-process result measured approximately 300 PCM units at
440 Hz and less than 0.001 at 880 Hz; this finite, quantized synthetic control
does not prove isolation for every process topology or output device. System
output measured approximately 300 units at each frequency. Audio stayed on the Mac.
The test players remained running until harness cleanup; no recorder or player
remained afterward. This does not establish audible playback preservation,
tap/aggregate destruction success, or the native recorder exit status obtained
through LaunchServices.

These tests demonstrate known-signal acquisition and two-process selection on
this host after explicit consent. Denied-permission behavior, native resource
cleanup, playback preservation, other device configurations, and Bridge/MCP
integration remain validation gates. An enabled Settings switch alone did not
establish that all pending consent dialogs had been answered.

### Denial, revocation, and checked teardown (2026-10-11)

Inspectable, redacted terminal receipts and measurements are committed in
[`evidence/system-audio-consent-2026-10-11.json`](evidence/system-audio-consent-2026-10-11.json).
The original October 11 allowed-capture receipts are included, along with current
matching-build controls. Paths, PIDs, hostnames, IPs, private bundle identifiers,
and endpoints are omitted. Recordings stayed on the test host; the artifact contains
derived signal measurements, PCM/CAF digests, and recorder receipts rather than
potentially unrelated system audio.

The recorder now checks native stop, IOProc destruction, aggregate destruction,
and tap destruction **before** publishing the final CAF or success receipt. Successful
receipts include those four OSStatus results. A failure keeps publication blocked;
the isolated deadline still bounds stalled native calls. This verifies successful
native teardown API results on the tested paths, not arbitrary failure recovery.

| Control on checked-teardown build | Evidence | Result |
| --- | --- | --- |
| Denied prototype consent; selected process plays 440 Hz | Explicit Don't Allow, then OFF state; final CAF has 200,704 frames, zero float32 nonzero samples and zero decoded PCM16 nonzero samples | No protected samples persisted; a silent CAF and warning are produced |
| Allowed process selection; simultaneous 440/880 Hz sources | 151,552 frames; interior 440 Hz amplitude about 300 PCM16 units and 880 Hz below 0.001 | Selected synthetic source captured |
| Allowed system output; simultaneous 440/880 Hz sources | 145,408 frames; both interior amplitudes about 300 PCM16 units | Both synthetic sources captured |
| Consent ON at start, then verified OFF during retained system tap | OFF observed at harness +9.14075 s; new 1320 Hz source started at +9.18234 s; marker appears at about 300 PCM16 units in later final-CAF windows | **Failed revocation boundary; merge blocked** |

The revocation run produced 1,531,392 frames and a final CAF. It kept both players
running until harness cleanup, and native stop/destruction results were all zero.
The marker source did not exist before the OFF observation, so its persistence
cannot be explained by draining only previously authorized, queued audio. The
next fresh capture under the same revoked host identity produced 191,488 frames
with zero nonzero samples, while the retained-tap run had persisted the new marker.
That control distinguishes the observed retained-resource behavior from an OFF
switch that merely failed to change new-capture access. The
permission observation clock is relative to harness start; analysis windows are
relative to the first recorded frame and must not be treated as the same time axis.
This establishes the Settings-OFF behavior on macOS 26.7; it does not establish
Apple's intended effective-revocation contract or a portable OS guarantee.

An experimental per-write tap-property round-trip did not establish a solution
and was reverted. Core Audio tap creation, silence, a live source process, and an
enabled Settings switch are not substitutes for a proven revocation-aware write
boundary. The requested negative revocation proof is not available: the live
control demonstrates the opposite. No security clearance is claimed.

For local reanalysis, convert a retained private CAF to signed 16-bit WAV with
`afconvert -f WAVE -d LEI16 INPUT.caf OUTPUT.wav`, then run
`python3 scripts/analyze-system-audio-proof.py OUTPUT.wav`. The script prints no
paths or process identifiers. Its one-second first-channel sine/cosine projections
are finite tone tests, not a general audio-isolation proof. The denied-control
receipt also reports exact float32 nonzero counts before PCM16 conversion.

Playback is configured as `CATapMuteBehavior.unmuted`; both test players remained
running. Apple documents that policy as forwarding audio to hardware as well as
the tap ([CATapMuteBehavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior)).
An independent hardware-output or human listening check was not performed, so
audible playback preservation remains open. Human maintainer approval of the
standalone feasibility scope is also still required.

After proving the native lifecycle, move capture APIs into the shared automation layer and expose them as
`capture audio` plus an MCP operation. Native work needs a separately contained worker,
with verified permission attribution and explicit typed capability negotiation. Return
actionable native errors and artifact/statistics metadata. Do not silently widen
a failed PID selection to global capture or fall back to the microphone.

Add process discovery with PID/generation evidence, per-app process selection,
bounded duration/size, cancellation/disconnect cleanup, denied-permission tests,
output-path validation, and two-process tone-isolation proof. Check system-audio
authorization separately from screen-recording authorization; do not assume an
existing ScreenCaptureKit grant proves that a Core Audio tap is permitted.
Finish with the repository's required checks and live Bridge/MCP tests before a PR.
The observed HAL stop stall also needs reproduction with an authorized host and
native timeout/isolation design before allowing a capture request to block the Bridge.

Do not install this probe over the existing Peekaboo app. Compile and authorize it
as a separate executable; a grant for another helper does not establish its consent.
