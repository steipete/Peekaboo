# Peekaboo Release Guide

This document describes the complete release and distribution process for Peekaboo, including Homebrew, npm, and GitHub releases.

## Overview

Peekaboo supports multiple distribution channels:
- **Homebrew tap** - Easy installation and updates for macOS users
- **npm package** - For Node.js users and MCP server deployment
- **GitHub releases** - Direct binary downloads with checksums
- **Source builds** - For developers and custom installations

## Release Infrastructure

### Scripts and Tools

1. **Release Script** (`scripts/release-binaries.sh`)
   - Comprehensive release automation
   - Runs pre-release checks (tests, linting, version sync)
   - Builds universal binary (arm64 + x86_64)
   - Creates release artifacts (tarball, npm package)
   - Generates SHA256 checksums
   - Optionally creates GitHub releases
   - Optionally publishes to npm

2. **Homebrew Formula Update** (`scripts/update-homebrew-formula.sh`)
   - Updates formula with new version and checksum
   - Can be run manually or via GitHub Actions

3. **GitHub Actions** (`.github/workflows/update-homebrew.yml`)
   - Automatically triggers on GitHub release publication
   - Updates Homebrew formula in tap repository
   - Creates pull request with changes

### Directory Structure

```
release/                    # Release artifacts (git-ignored)
├── peekaboo-v2.0.1-darwin-universal.tar.gz
├── peekaboo-v2.0.1-darwin-universal.tar.gz.sha256
├── peekaboo-mcp-2.0.1.tgz
└── checksums.txt

homebrew/                   # Homebrew formula template
└── peekaboo.rb

scripts/                    # Release automation
├── release-binaries.sh
├── update-homebrew-formula.sh
└── build-swift-universal.sh
```

## Initial Setup

### 1. Create Homebrew Tap Repository

```bash
# Create new repository on GitHub named: homebrew-tap
# Then clone and set up:
git clone git@github.com:steipete/homebrew-tap.git
cd homebrew-tap
mkdir Formula
cp /path/to/peekaboo/homebrew/peekaboo.rb Formula/
git add .
git commit -m "Initial formula for Peekaboo"
git push
```

### 2. Configure GitHub Secrets

For automated Homebrew updates:
1. Create a GitHub Personal Access Token at https://github.com/settings/tokens/new
   - Scopes needed: `repo` (for creating PRs in tap repository)
2. Add as `HOMEBREW_TAP_TOKEN` in main repository secrets

For npm publishing:
1. Get npm access token: `npm login` then `cat ~/.npmrc`
2. Add as `NPM_TOKEN` in repository secrets

## Release Process

### 1. Prepare Release

```bash
# Update version in package.json
npm version minor  # or major/patch

# Update CHANGELOG.md with release notes
# Include:
# - New features
# - Bug fixes
# - Breaking changes
# - Contributors

# Commit changes
git add package.json package-lock.json CHANGELOG.md
git commit -m "Release v2.0.1"
```

### 2. Run Pre-Release Checks

```bash
# Test the release process without publishing
./scripts/release-binaries.sh --dry-run

# Or run checks manually:
npm test
npm run lint:swift
npm run build:all
```

### 3. Create Release

```bash
# Tag the release
git tag v2.0.1
git push origin main --tags

# Create full release with all channels
./scripts/release-binaries.sh --create-github-release --publish-npm

# Or selectively:
./scripts/release-binaries.sh --create-github-release  # GitHub only
./scripts/release-binaries.sh --publish-npm            # npm only
./scripts/release-binaries.sh                          # Local artifacts only
```

### 4. Verify Release

1. **GitHub Release**: Check https://github.com/steipete/peekaboo/releases
2. **npm Package**: Verify with `npm view @steipete/peekaboo-mcp`
3. **Homebrew Formula**: PR should be created in tap repository
4. **Test Installation**:
   ```bash
   # Homebrew
   brew tap steipete/tap
   brew install peekaboo
   
   # npm
   npm install -g @steipete/peekaboo-mcp
   ```

## Release Artifacts

Each release creates:

1. **Universal Binary Tarball**
   - `peekaboo-v{VERSION}-darwin-universal.tar.gz`
   - Contains pre-built Swift CLI binary
   - Supports both Apple Silicon and Intel Macs

2. **npm Package**
   - `peekaboo-mcp-{VERSION}.tgz`
   - Includes TypeScript server and bundled Swift binary
   - Ready for `npm publish`

3. **Checksums**
   - Individual `.sha256` files for each artifact
   - Combined `checksums.txt` for all artifacts

## Version Management

- Version is centrally managed in `package.json`
- Swift CLI reads version from package.json during build
- All release scripts validate version consistency
- Follow semantic versioning (MAJOR.MINOR.PATCH)

## Troubleshooting

### Common Issues

1. **Version Mismatch**
   ```bash
   # Ensure git tag matches package.json
   git tag -d v2.0.1  # Delete local tag
   git push origin :refs/tags/v2.0.1  # Delete remote tag
   npm version 2.0.1 --no-git-tag-version  # Fix version
   git add . && git commit -m "Fix version"
   git tag v2.0.1
   ```

2. **Build Failures**
   ```bash
   # Clean and rebuild
   npm run clean
   npm run build:all
   
   # Check Swift toolchain
   swift --version  # Should be 5.9+
   ```

3. **Formula Update Failed**
   - Check HOMEBREW_TAP_TOKEN is set correctly
   - Ensure token has repo scope
   - Manually update: `./scripts/update-homebrew-formula.sh v2.0.1`

## Manual Homebrew Formula Update

If automated update fails:

```bash
# Update formula manually
./scripts/update-homebrew-formula.sh v2.0.1

# Copy to tap repository
cp homebrew/peekaboo.rb ../homebrew-tap/Formula/

# Create PR manually
cd ../homebrew-tap
git checkout -b update-v2.0.1
git add Formula/peekaboo.rb
git commit -m "Update Peekaboo to v2.0.1"
git push origin update-v2.0.1
# Create PR on GitHub
```

## Testing Releases

### Local Testing

```bash
# Test binary directly
./release/peekaboo-v2.0.1-darwin-universal/peekaboo --version

# Test npm package
npm pack  # Creates .tgz
npm install -g peekaboo-mcp-2.0.1.tgz
peekaboo-mcp --version
```

### Integration Testing

```bash
# Test with MCP Inspector
npx @modelcontextprotocol/inspector npx @steipete/peekaboo-mcp@latest

# Test specific version
npx @modelcontextprotocol/inspector npx @steipete/peekaboo-mcp@2.0.1
```

## Release Checklist

- [ ] All tests passing (`npm test`)
- [ ] Swift code linted (`npm run lint:swift`)
- [ ] Version updated in package.json
- [ ] CHANGELOG.md updated
- [ ] Changes committed and pushed
- [ ] Git tag created and pushed
- [ ] Release script run successfully
- [ ] GitHub release verified
- [ ] npm package published and verified
- [ ] Homebrew formula PR created/merged
- [ ] Installation tested on clean system

## Distribution Channels Summary

| Channel | Installation | Update | Notes |
|---------|-------------|---------|--------|
| Homebrew | `brew install steipete/tap/peekaboo` | `brew upgrade peekaboo` | Recommended for macOS users |
| npm | `npm install -g @steipete/peekaboo-mcp` | `npm update -g` | For Node.js environments |
| GitHub | Download from releases | Manual download | Direct binary access |
| Source | `npm run build:all` | `git pull && npm run build:all` | For developers |

## Security Considerations

- All releases are signed with SHA256 checksums
- Homebrew verifies checksums during installation
- npm packages are published with provenance when possible
- Consider code signing for future releases

## Future Enhancements

- [ ] Automated changelog generation from commits
- [ ] Code signing for macOS binaries
- [ ] Automated testing of installation methods
- [ ] Beta/pre-release channel support
- [ ] Cross-platform release support (when applicable)