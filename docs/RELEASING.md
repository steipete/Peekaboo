---
summary: 'Peekaboo 3.x release checklist (main repo + submodules)'
read_when:
  - 'preparing for a release'
  - 'cleaning up repos before release'
---

# Peekaboo Release Checklist

> **Runner note:** From the repo root run everything through `./runner …` unless a step says otherwise. For long Swift builds/tests, use tmux as documented in AGENTS.
>
> **No-warning policy:** Lint/format/build/test steps must finish cleanly (no SwiftLint/SwiftFormat warnings, no pnpm warnings). Fix issues before moving on.

**Scope:** Main Peekaboo repo plus submodules `/AXorcist`, `/Commander`, `/Tachikoma`, `/TauTUI`. Each has its own `CHANGELOG.md` and must be released in lock-step.

## 0) Version + metadata prep
- [ ] Bump versions: `package.json`, `version.json`, app Info.plists (CLI + macOS targets), and all MCP server/tool banners (`Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/**`).
- [ ] Cut `CHANGELOG.md`: move items from **Unreleased** into the new 3.x section with the correct date.
- [ ] Align docs that mention the version (`docs/tui.md`, `docs/reports/playground-test-result.md`, `AGENTS.md`, any beta strings).
- [ ] Submodules: bump versions + changelogs in AXorcist, Commander, Tachikoma, TauTUI before updating submodule SHAs here.

## 1) Format & lint (all repos)
- [ ] Main: `pnpm run format:swift`, `pnpm run lint:swift`, plus `pnpm run format` / `pnpm run lint` if JS/TS changed.
- [ ] AXorcist: `swift run swiftformat .` then `swiftlint`.
- [ ] Commander: `swift run swiftformat .` then `swiftlint`.
- [ ] Tachikoma: `swift run swiftformat .` then `swiftlint`.
- [ ] TauTUI: `swift run swiftformat .` then `swiftlint`.

## 2) Tests & builds
- [ ] Main Swift build: `swift build`.
- [ ] Main tests: `(cd Apps/CLI && swift test)`; remove or rewrite any constructs that trigger the known SILGen/frontend crash before continuing.
- [ ] JS/TS tests: `pnpm test` (and `pnpm check` if applicable).
- [ ] Submodules: `swift build && swift test` in AXorcist, Commander, Tachikoma, TauTUI.
- [ ] Optional automation sweep: `pnpm run test:automation` when touching agent flows.

## 3) Release artifacts
- [ ] `pnpm run prepare-release` (validates versions, changelog, and Swift/TS entry points).
- [ ] `./scripts/release-binaries.sh --create-github-release --publish-npm` (Poltergeist builds universal binaries and the npm package; expect a multi-minute run).
- [ ] Verify `dist/` outputs and the generated checksum files.
- [ ] `npm pack --dry-run` to inspect the npm tarball if release scripts changed.

## 3b) macOS app (Sparkle)
Peekaboo’s macOS app now ships Sparkle updates (Settings → About). Updates are **disabled** unless the app is a bundled `.app` and **Developer ID signed** (see `Apps/Mac/Peekaboo/Core/Updater.swift`).

- [ ] Ensure `Apps/Mac/Peekaboo/Info.plist` has `SUFeedURL`, `SUPublicEDKey`, and `SUEnableAutomaticChecks` set (defaults are already wired to the repo appcast).
- [ ] Build and **Developer ID sign** the Release `.app` (Xcode Archive + Export is fine).
- [ ] Zip for Sparkle distribution (keeps resource forks, needed for delta support):
  - `ditto -c -k --sequesterRsrc --keepParent "Peekaboo.app" "Peekaboo-<version>.zip"`
- [ ] Generate the Sparkle signature and capture the **exact** length + `sparkle:edSignature`:
  - `sign_update --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "Peekaboo-<version>.zip"`
- [ ] Upload the zip to the GitHub Release assets.
- [ ] Update `appcast.xml` (repo root) with a new `<item>` pointing at the GitHub Release asset URL, using the **exact** `length` and `sparkle:edSignature` from `sign_update`.
- [ ] Verify with an installed previous build: Settings → About → “Check for Updates…” installs the new build.

## 4) Git hygiene
- [ ] Commit and push submodules first (conventional commits in each subrepo).
- [ ] Update submodule pointers in the main repo and commit via `./scripts/committer`.
- [ ] Commit main repo release changes (changelog, version bumps, generated assets if tracked) via `./scripts/committer`.
- [ ] `./runner git status -sb` should be clean.

## 5) Tag & publish
- [ ] Tag the release: `git tag v<version>` then `git push --tags`.
- [ ] Publish npm if the release script didn’t: `pnpm publish --tag latest`.
- [ ] Create GitHub release: upload macOS binaries/tarballs + checksum, and include release notes with Highlights + SHA256.

## 6) Post-publish verification
- [ ] `polter peekaboo --version` to confirm the stamped build date matches the new tag.
- [ ] `npm view peekaboo version` to ensure the registry shows the new version.
- [ ] Homebrew tap: update `steipete/homebrew-tap` formula for Peekaboo with new URL + SHA256, commit, push, then `brew install steipete/tap/peekaboo && peekaboo --version`.
- [ ] Fresh-temp smoke: `rm -rf /tmp/peekaboo-empty && mkdir /tmp/peekaboo-empty && cd /tmp/peekaboo-empty && npx peekaboo@<version> --help` (no runner; outside repo). Ensure CLI/help prints and exits 0.

## Quick status helpers
```bash
./runner git status -sb
./runner git submodule status
```

## Notes
- Conventional Commits only. Submodules first, main repo last.
- No stale binaries: run user-facing tests/verification via `polter peekaboo …` so the built binary matches the tree.
