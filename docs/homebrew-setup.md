---
summary: 'Review Setting Up Homebrew Tap for Peekaboo guidance'
read_when:
  - 'planning work related to setting up homebrew tap for peekaboo'
  - 'debugging or extending features described here'
---

# Setting Up Homebrew Tap for Peekaboo

This guide explains how to set up and maintain the Homebrew tap for Peekaboo distribution.

## Repository Structure

The Homebrew tap is hosted at [github.com/steipete/homebrew-tap](https://github.com/steipete/homebrew-tap).

### Key Files

- **Formula/peekaboo.rb**: The Homebrew formula that defines how to install Peekaboo
- **.github/workflows/update-formula.yml**: GitHub Action to update the formula when new releases are published
- **README.md**: User-facing documentation for the tap

## Initial Setup (Already Complete)

The tap repository has been created and initialized with:
- Initial formula at `Formula/peekaboo.rb`
- GitHub Action workflow for automated updates
- README with installation instructions

### Setting Up GitHub Token

For automated updates from the main repository:

1. Go to https://github.com/settings/tokens/new
2. Create a token with `repo` scope
3. Name it `HOMEBREW_TAP_TOKEN`
4. Add to main repo secrets: Settings → Secrets → Actions → New repository secret

## Usage

### Installing Peekaboo via Homebrew

Users can now install Peekaboo with:

```bash
brew tap steipete/tap
brew install peekaboo
```

### Updating Peekaboo

```bash
brew update
brew upgrade peekaboo
```

## Release Process

### Automated (Recommended)

When you create a GitHub release, the workflow automatically:
1. Downloads the release artifact
2. Calculates SHA256
3. Updates the formula in both repos
4. Creates a PR in the main repo

### Manual Update

If needed, update the formula manually:

```bash
# After building release artifacts
./scripts/release-binaries.sh

# Get the SHA256
shasum -a 256 release/peekaboo-macos-arm64.tar.gz

# Update formula
./scripts/update-homebrew-formula.sh 2.0.1 <sha256>

# Push to tap
cd /path/to/homebrew-tap
git pull
cp /path/to/peekaboo/homebrew/peekaboo.rb Formula/
git add Formula/peekaboo.rb
git commit -m "Update to v2.0.1"
git push
```

## Testing

### Test Installation

```bash
# Test from your tap
brew tap steipete/tap
brew install --verbose --debug peekaboo
brew test peekaboo
```

### Test Formula Locally

```bash
# Direct install from formula file
brew install --build-from-source ./homebrew/peekaboo.rb
```

## Troubleshooting

### Common Issues

1. **SHA256 Mismatch**
   - Ensure you're using the final release artifact
   - Use `shasum -a 256` on macOS

2. **Download Failures**
   - Check the URL is correct
   - Ensure the release is published (not draft)

3. **Permission Errors**
   - The formula includes post_install to ensure executable permissions

### Debugging

```bash
# Verbose installation
brew install --verbose --debug peekaboo

# Check tap
brew tap-info steipete/peekaboo

# Audit formula
brew audit --strict steipete/peekaboo/peekaboo
```

## Maintenance

### Updating Dependencies

If macOS requirements change:
```ruby
depends_on macos: :ventura  # For macOS 13+
```

### Adding Cask (Future)

For a full GUI app distribution:
```ruby
cask "peekaboo" do
  version "2.0.0"
  sha256 "..."
  
  url "https://github.com/steipete/peekaboo/releases/download/v#{version}/Peekaboo.app.zip"
  name "Peekaboo"
  desc "Screenshot and AI analysis tool"
  homepage "https://github.com/steipete/peekaboo"
  
  app "Peekaboo.app"
end
```

## Best Practices

1. **Version Tags**: Always use `v` prefix (e.g., `v2.0.0`)
2. **Testing**: Test formula locally before pushing
3. **Checksums**: Always verify SHA256 after building
4. **Release Notes**: Update formula caveats for major changes
5. **Compatibility**: Test on both Intel and Apple Silicon

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Taps](https://docs.brew.sh/Taps)
- [GitHub Actions for Homebrew](https://brew.sh/2020/11/18/homebrew-tap-with-bottles-uploaded-to-github-releases/)
