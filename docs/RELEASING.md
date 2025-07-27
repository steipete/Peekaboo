# Peekaboo Release Guide

This document describes the complete release process for Peekaboo, including all distribution channels: Homebrew, npm, and GitHub releases.

## Overview

Peekaboo supports multiple distribution channels:
- **Homebrew tap** - Easy installation and updates for macOS users
- **npm package** - For Node.js users and MCP server deployment  
- **GitHub releases** - Direct binary downloads with checksums
- **Source builds** - For developers and custom installations

## Release Infrastructure

### Scripts and Tools

1. **Release Preparation** (`scripts/prepare-release.js`)
   - Comprehensive pre-release validation
   - Checks git status, dependencies, security, version consistency
   - Validates TypeScript and Swift builds
   - Ensures changelog is updated
   - Tests MCP server functionality

2. **Release Script** (`scripts/release-binaries.sh`)
   - Comprehensive release automation
   - Builds universal binary (arm64 + x86_64)
   - Creates release artifacts (tarball, npm package)
   - Generates SHA256 checksums
   - Optionally creates GitHub releases
   - Optionally publishes to npm

3. **Homebrew Formula Update** (`scripts/update-homebrew-formula.sh`)
   - Updates formula with new version and checksum
   - Can be run manually or via GitHub Actions

4. **GitHub Actions** (`.github/workflows/update-homebrew.yml`)
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
├── prepare-release.js
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
git commit -m "Prepare release vX.Y.Z"
```

### 2. Run Automated Pre-Release Checks

```bash
# Run comprehensive release preparation
npm run prepare-release
```

This script performs:
- **Git Status**: Ensures you're on main branch with no uncommitted changes
- **Required Fields**: Validates all required fields in package.json
- **Dependencies**: Checks for missing or outdated dependencies
- **Security Audit**: Runs npm audit to check for vulnerabilities
- **Version Availability**: Confirms the version isn't already published
- **Version Consistency**: Ensures package.json and package-lock.json versions match
- **Changelog Entry**: Verifies CHANGELOG.md has an entry for the current version
- **TypeScript**: Compiles and runs tests
- **TypeScript Declarations**: Verifies .d.ts files are generated
- **Swift**: Runs format, lint, and tests
- **Build Verification**: Builds everything and verifies the package
- **Package Size**: Warns if package exceeds 2MB
- **MCP Server Smoke Test**: Tests the server with a simple JSON-RPC request

### 3. Test Local Compilation

**MANDATORY**: Compile and run local tests to ensure they build correctly.

```bash
# Run CI-compatible Swift tests
cd Apps/CLI && swift test

# Optionally test local-only functionality
cd Apps/CLI/TestHost && swift run  # Start test host
cd Apps/CLI && RUN_LOCAL_TESTS=true swift test --filter LocalIntegration
```

### 4. Create Release

```bash
# Tag the release
git tag vX.Y.Z
git push origin main --tags

# Create full release with all channels
./scripts/release-binaries.sh --create-github-release --publish-npm

# Or selectively:
./scripts/release-binaries.sh --create-github-release  # GitHub only
./scripts/release-binaries.sh --publish-npm            # npm only
./scripts/release-binaries.sh                          # Local artifacts only
```

### 5. NPM Publish (if not using release script)

```bash
# Dry run to verify package contents
npm publish --access public --tag beta --dry-run  # For pre-releases
npm publish --access public --dry-run              # For stable releases

# Actual publish
npm publish --access public --tag beta  # For pre-releases
npm publish --access public             # For stable releases
```

### 6. Verify Release

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
   
   # Test with MCP Inspector
   npx @modelcontextprotocol/inspector npx @steipete/peekaboo-mcp@latest
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
   git tag -d vX.Y.Z  # Delete local tag
   git push origin :refs/tags/vX.Y.Z  # Delete remote tag
   npm version X.Y.Z --no-git-tag-version  # Fix version
   git add . && git commit -m "Fix version"
   git tag vX.Y.Z
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
   - Manually update: `./scripts/update-homebrew-formula.sh vX.Y.Z`

## Manual Homebrew Formula Update

If automated update fails:

```bash
# Update formula manually
./scripts/update-homebrew-formula.sh vX.Y.Z

# Copy to tap repository
cp homebrew/peekaboo.rb ../homebrew-tap/Formula/

# Create PR manually
cd ../homebrew-tap
git checkout -b update-vX.Y.Z
git add Formula/peekaboo.rb
git commit -m "Update Peekaboo to vX.Y.Z"
git push origin update-vX.Y.Z
# Create PR on GitHub
```

## Release Checklist

- [ ] All tests passing (`npm test`)
- [ ] Swift code linted (`npm run lint:swift`)
- [ ] Version updated in package.json
- [ ] CHANGELOG.md updated with release notes
- [ ] Documentation updated (README.md, spec.md if needed)
- [ ] Release preparation script run (`npm run prepare-release`)
- [ ] Local Swift tests compiled and passed
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

## Post-Release Steps

1. **Create GitHub Release** (if not using automated script):
   - Go to the GitHub repository's "Releases" section
   - Draft a new release, selecting the tag you just pushed
   - Copy the relevant section from CHANGELOG.md into the release description
   - Attach build artifacts if desired

2. **Announce the Release** (Optional):
   - Team chat, Twitter, project website
   - Include major features and breaking changes

## Future Enhancements

- [ ] Automated changelog generation from commits
- [ ] Code signing for macOS binaries
- [ ] Automated testing of installation methods
- [ ] Beta/pre-release channel support
- [ ] Cross-platform release support (when applicable)

---

**Note**: The `prepublishOnly` script in package.json ensures the project is always built before publishing.