# Namespace CI Setup for Peekaboo

This guide documents the setup process for using Namespace's faster macOS CI machines.

## Why Namespace?

- **Faster Builds**: M2 Pro/M4 Pro hardware vs GitHub's Intel-based runners
- **Scalable Resources**: From 1 vCPU/2GB to 32 vCPU/512GB RAM
- **Better Performance**: Consistent hardware, high-throughput caching
- **Cost Effective**: Competitive pricing for macOS runners

## Setup Steps

### 1. Create Namespace Account

1. Visit [namespace.so](https://namespace.so) and sign up
2. Connect your GitHub organization
3. Install the Namespace GitHub App

### 2. Create Runner Profiles

In your Namespace dashboard, create two runner profiles:

**Profile 1: Standard macOS Runner**
- Name: `peekaboo-macos`
- Machine Type: macOS ARM64
- Resources: 4 vCPU, 8GB RAM
- Use for: Regular tests and builds

**Profile 2: Large macOS Runner**
- Name: `peekaboo-macos-large`
- Machine Type: macOS ARM64
- Resources: 8 vCPU, 16GB RAM
- Use for: Swift builds and intensive tests

### 3. Update GitHub Workflows

Replace `runs-on: macos-15` with:
- `runs-on: namespace-profile-peekaboo-macos` for standard jobs
- `runs-on: namespace-profile-peekaboo-macos-large` for build-intensive jobs

### 4. Migration Strategy

1. Keep both workflows during transition:
   - `.github/workflows/ci.yml` - Original GitHub runners
   - `.github/workflows/ci-namespace.yml` - Namespace runners

2. Test the Namespace workflow thoroughly
3. Once stable, update the main `ci.yml` to use Namespace
4. Remove the temporary `ci-namespace.yml`

## Expected Performance Improvements

Based on Namespace's benchmarks with M2 Pro hardware:
- Swift builds: 2-3x faster
- Test execution: 2x faster
- Overall CI time: ~50% reduction

## Monitoring and Debugging

Namespace provides:
- Real-time runner logs
- SSH access for debugging
- Performance metrics
- Cost tracking dashboard

## Caching Strategy

Optimize builds with Namespace's caching:

```yaml
- name: Cache Swift dependencies
  uses: namespace/cache@v1
  with:
    path: |
      .build
      ~/Library/Developer/Xcode/DerivedData
    key: ${{ runner.os }}-swift-${{ hashFiles('**/Package.resolved') }}
```

## Cost Considerations

- Pay per minute of usage
- No idle charges
- Automatic scaling based on demand
- Monitor usage in Namespace dashboard

## Troubleshooting

### Xcode Version Issues
If Xcode is not available:
```yaml
- name: Install Xcode
  uses: namespace/setup-xcode@v1
  with:
    xcode-version: '16.4'
```

### Permission Issues
Namespace runners have sudo access by default, but verify:
```yaml
- name: Check permissions
  run: |
    whoami
    sudo -n true && echo "Sudo works without password"
```

## Next Steps

1. Monitor initial runs for any issues
2. Optimize caching for better performance
3. Consider custom base images for faster startup
4. Set up cost alerts in Namespace dashboard