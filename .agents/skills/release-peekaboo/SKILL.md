---
name: release-peekaboo
description: "Prepare, publish and verify Peekaboo through its hosted GitHub Actions release workflow."
metadata: {"clawdbot":{"emoji":"👁️","requires":{"bins":["pnpm","gh","git","node","npm"]}}}
---

# Peekaboo Release

Read [docs/RELEASING.md](../../../docs/RELEASING.md) first; it is the source of
truth. Follow repo `AGENTS.md`. Only `.github/workflows/release.yml` publishes
`openclaw/Peekaboo` and `@steipete/peekaboo`. Never release or publish without an
explicit release command; a rehearsal does not authorize publication.

1. Prepare a PR with consistent version surfaces and dated root/CLI changelog
   sections, validated by the existing release preflight. Hosted Actions extracts
   notes from `CHANGELOG.md`; no separate notes file or local publisher is used.
   Merge the preparation PR and wait for green **push CI on that exact commit**.
2. Rehearse from main with
   `gh workflow run release.yml --ref main -f version=X.Y.Z -F dry_run=true`.
   Review the frozen source and artifacts, approve the `release` environment,
   and verify the run succeeds without publication.
3. With explicit publication authorization, create and push an annotated
   SSH-signed `vX.Y.Z` tag on the same verified commit, using the canonical release
   SSH key accepted by `.github/release-allowed-signers`. Resolve that key through
   the private credential guidance if needed; never copy private key material
   into the repo. Approve the publication run's `release` environment gate.
   Tag pushes also trigger other workflows; the release CI gate fails while
   checks are still running. Wait for them to succeed, then rerun failed release
   jobs as needed. Never replace a published tag or rebuild an existing version.
4. Verify GitHub Release assets and `checksums.txt`, and compare the published
   notes to the root changelog. Check npm's exact version, dist-tag, tarball,
   integrity and publish time; compare the downloaded registry tarball's SHA-512
   integrity with the exact tarball from the hosted run. Run published CLI proof
   with `npm exec` from `/tmp` so the checkout cannot shadow the package.
5. Verify the Homebrew tap formula's version, URLs and checksums. Review and merge
   the Actions-created appcast closeout PR, then verify the feed on main and the
   post-release `Unreleased` section. Report the release/run/closeout links and
   any incomplete handoff. Retry hosted handoffs only after checking what is
   already published; do not overwrite an existing version.

Signing/notarization credentials stay in the hosted `release` environment; npm
uses OIDC. Local terminal/fleet notarization helpers are qualification tools and
are not an alternate publication path.
