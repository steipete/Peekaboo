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

Prepare all version surfaces using the existing release preflight, date the root
and CLI changelog sections, and set `release/release-notes.md` to the root version's
notes. Merge the preparation PR to protected main and wait for green push CI on
the exact commit. A release requires separate explicit authorization.

First dispatch `release.yml` from main with the prepared `version` and
`dry_run=true` (the default). It builds, signs, notarizes and independently
verifies without creating a tag, release, npm publication, tap update or appcast
PR. The `release` environment remains approval-gated. Review its frozen source
and artifacts before approving the signing job.

For publication, push an annotated SSH-signed `vX.Y.Z` tag accepted by
`.github/release-allowed-signers`. The hosted workflow refuses mismatched version
metadata and never replaces a version tag. Signed macOS payloads and the exact
npm tarball are verified before publication. Failed handoffs can be retried by
the corresponding hosted workflow after checking published integrity; do not
rebuild or overwrite an existing version.

The caller pins the immutable release-workflows `v1.11.4` tag, which includes zippered
macOS runtime validation (`openclaw/release-workflows#75`) and legacy appcast build
numbers (#76). Return to the fleet `@v1` compatibility tag once `v1` points at 1.11.4
or newer.
`npm-publish.yml` must keep its filename: the trusted publisher for
`@steipete/peekaboo` names it. No npm token is needed.

The `release` environment needs `MACOS_SIGNING_P12`,
`MACOS_SIGNING_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_PRIVATE_KEY_P8` and `SPARKLE_PRIVATE_KEY`. The repository's
`HOMEBREW_TAP_TOKEN` handles the tap handoff. No security settings are changed by
this workflow. Local source, native artifact, package-resolution, signature and
archive verification helpers remain available for development.
