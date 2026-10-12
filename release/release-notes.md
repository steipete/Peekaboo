## 4.9.2 - 2026-10-12

**Highlights:** Create CLI child-process pipes close-on-exec with Swift Subprocess 1.0.1 so they no longer leak into other children, build signed and notarized releases on GitHub Actions behind an approval gate, and keep local notarization working on congested uplinks with a parallel Notary API upload fallback.

- Update Swift Subprocess to 1.0.1 for close-on-exec pipe handling and single-owner output-descriptor cleanup in CLI child processes, preserving the Swift 6.2 and macOS baselines.
- Add an approval-gated GitHub Actions release path for signed and notarized universal app, DMG, CLI, npm, and Homebrew deliverables, with independent artifact verification and an appcast closeout PR.
- Fall back to parallel Notary REST uploads for terminal-qualification notarization when API-key notarization hits a notarytool transport failure, with explicit transport selection, bounded retries, and unchanged artifact verification.
