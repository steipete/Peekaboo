---
summary: 'Release Peekaboo through verified GitHub Actions artifacts.'
read_when:
  - 'preparing or verifying a Peekaboo release'
---

# Releasing Peekaboo

The sole publication path is `.github/workflows/release.yml`. It builds the app,
DMG, standalone CLI archives and npm package, signs with the OpenClaw Foundation
Developer ID, notarizes, verifies on arm64 and Intel, publishes a checksummed
GitHub Release, hands off the exact npm tarball through OIDC and updates Homebrew.
The hosted app build explicitly targets arm64 and x86_64 and rejects a thin binary
before signing. The closeout PR publishes the signed Sparkle appcast to main. No laptop publisher
or upload fallback remains.

Prepare all version surfaces using the existing release preflight and date the
root and CLI changelog sections. The hosted workflow extracts release notes
directly from the matching version in `CHANGELOG.md`, skipping fenced code; no
separate release-notes file is maintained. Merge the preparation PR to protected
main and wait for green push CI on the exact commit. A release requires separate
explicit authorization.

First dispatch `release.yml` from main with the prepared `version` and
`dry_run=true` (the default). It builds, signs, notarizes and independently
verifies without creating a tag, release, npm publication, tap update or appcast
PR. The `release` environment remains approval-gated. Review its frozen source
and artifacts before approving the signing job.

```sh
gh workflow run release.yml --ref main -f version=X.Y.Z -F dry_run=true
```

For publication, push an annotated SSH-signed `vX.Y.Z` tag accepted by
`.github/release-allowed-signers`, using the canonical release SSH key and the
same verified commit. Review and approve the publication run's `release`
environment gate too. GitHub tag pushes also trigger other workflows: the release
CI gate rejects still-running checks, so wait for those checks to finish and
rerun the failed release jobs if needed. The hosted workflow refuses mismatched
version metadata and never replaces a version tag. Signed macOS payloads and the
exact npm tarball are verified before publication. Failed handoffs can be retried
by the corresponding hosted workflow after checking published integrity; do not
rebuild or overwrite an existing version.

Before closeout, verify the GitHub Release assets against `checksums.txt`, and
confirm the published notes match the dated root changelog. Check npm's exact
version, dist-tag, tarball, integrity and publish time with
`npm view @steipete/peekaboo@X.Y.Z version dist-tags dist.tarball dist.integrity time --json`;
download that registry tarball and compare its SHA-512 integrity with the exact
tarball retained by the hosted run. Verify the Homebrew tap formula's version,
asset URLs and checksums. Review and merge the Actions-created appcast closeout
PR, verify the feed on main, and follow the existing post-release `Unreleased`
changelog convention. Publication is not complete while that PR is unmerged.

The caller pins the fleet release-workflows `@v1` compatibility tag, which points at
1.11.4 or newer: zippered macOS runtime validation (`openclaw/release-workflows#75`)
and legacy appcast build numbers (#76).
`npm-publish.yml` must keep its filename: the trusted publisher for
`@steipete/peekaboo` names it. No npm token is needed.

The `release` environment needs `MACOS_SIGNING_P12`,
`MACOS_SIGNING_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_PRIVATE_KEY_P8` and `SPARKLE_PRIVATE_KEY`. The repository's
`HOMEBREW_TAP_TOKEN` handles the tap handoff. No security settings are changed by
this workflow. Local source, native artifact, package-resolution, signature and
archive verification helpers remain available for development.

## Terminal qualification notarization

`scripts/build-terminal-artifacts.sh` retains a separate fleet/qualification path;
it does not publish releases. Its `scripts/build-terminal-dmg.sh` uses the shared
locked `dmgbuild` runner and settings. `scripts/notarize-terminal-artifact.sh`
notarizes already-signed artifacts with `--notary-transport auto|notarytool|api`.
With API-key credentials, `auto` retries the retained submission bytes through
`scripts/notary-api-submit.py` after a notarytool transport failure, including a
failed history preflight. An Apple `Invalid` or `Rejected` verdict is not retried
through another transport. Existing keychain profiles use notarytool only;
`--notary-transport api` requires API-key credentials. This fallback preserves
the existing acceptance, stapling and final artifact-verification requirements.
