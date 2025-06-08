#!/bin/bash
set -e

# Peekaboo Shipping Validation Script
# Validates that the project is ready for cross-platform shipping

echo "🚀 Peekaboo Shipping Validation"
echo "==============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Track validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Function to increment error count
validation_error() {
    log_error "$1"
    ((VALIDATION_ERRORS++))
}

# Function to increment warning count
validation_warning() {
    log_warning "$1"
    ((VALIDATION_WARNINGS++))
}

# Check project structure
log_info "Checking project structure..."

# Required directories
REQUIRED_DIRS=(
    "peekaboo-cli"
    "peekaboo-cli/Sources"
    "peekaboo-cli/Sources/peekaboo"
    "peekaboo-cli/Sources/peekaboo/Platforms"
    "peekaboo-cli/Sources/peekaboo/Platforms/macOS"
    "peekaboo-cli/Sources/peekaboo/Platforms/Windows"
    "peekaboo-cli/Sources/peekaboo/Platforms/Linux"
    "peekaboo-cli/Tests"
    ".github"
    ".github/workflows"
    "scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        validation_error "Missing required directory: $dir"
    fi
done

# Required files
REQUIRED_FILES=(
    "README.md"
    "CONTRIBUTING.md"
    "FEATURE_PARITY_AUDIT.md"
    "peekaboo-cli/Package.swift"
    "peekaboo-cli/Sources/peekaboo/main.swift"
    "peekaboo-cli/Sources/peekaboo/Models.swift"
    "peekaboo-cli/Sources/peekaboo/PlatformFactory.swift"
    ".github/workflows/cross-platform-ci.yml"
    ".github/workflows/release.yml"
    "scripts/install.sh"
    "scripts/install.ps1"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        validation_error "Missing required file: $file"
    fi
done

log_success "Project structure validation complete"

# Check platform implementations
log_info "Checking platform implementations..."

# macOS platform files
MACOS_FILES=(
    "peekaboo-cli/Sources/peekaboo/Platforms/macOS/macOSScreenCapture.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/macOS/macOSApplicationFinder.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/macOS/macOSWindowManager.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/macOS/macOSPermissionChecker.swift"
)

# Windows platform files
WINDOWS_FILES=(
    "peekaboo-cli/Sources/peekaboo/Platforms/Windows/WindowsScreenCapture.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Windows/WindowsApplicationFinder.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Windows/WindowsWindowManager.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Windows/WindowsPermissionChecker.swift"
)

# Linux platform files
LINUX_FILES=(
    "peekaboo-cli/Sources/peekaboo/Platforms/Linux/LinuxScreenCapture.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Linux/LinuxApplicationFinder.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Linux/LinuxWindowManager.swift"
    "peekaboo-cli/Sources/peekaboo/Platforms/Linux/LinuxPermissionChecker.swift"
)

# Check macOS files
for file in "${MACOS_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        validation_error "Missing macOS implementation: $file"
    fi
done

# Check Windows files
for file in "${WINDOWS_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        validation_error "Missing Windows implementation: $file"
    fi
done

# Check Linux files
for file in "${LINUX_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        validation_error "Missing Linux implementation: $file"
    fi
done

log_success "Platform implementations validation complete"

# Check test files
log_info "Checking test implementations..."

TEST_FILES=(
    "peekaboo-cli/Tests/peekabooTests/IntegrationTests.swift"
    "peekaboo-cli/Tests/peekabooTests/PlatformFactoryTests.swift"
    "peekaboo-cli/Tests/peekabooTests/WindowsSpecificTests.swift"
    "peekaboo-cli/Tests/peekabooTests/LinuxSpecificTests.swift"
    "peekaboo-cli/Tests/peekabooTests/ShippingReadinessTests.swift"
)

for file in "${TEST_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        validation_error "Missing test file: $file"
    fi
done

log_success "Test implementations validation complete"

# Check CI/CD configuration
log_info "Checking CI/CD configuration..."

# Check GitHub Actions workflows
if [ -f ".github/workflows/cross-platform-ci.yml" ]; then
    # Check for required platforms in CI
    if ! grep -q "macos-14" ".github/workflows/cross-platform-ci.yml"; then
        validation_warning "CI workflow missing macOS 14 runner"
    fi
    if ! grep -q "ubuntu-latest" ".github/workflows/cross-platform-ci.yml"; then
        validation_warning "CI workflow missing Ubuntu runner"
    fi
    if ! grep -q "windows-latest" ".github/workflows/cross-platform-ci.yml"; then
        validation_warning "CI workflow missing Windows runner"
    fi
fi

# Check release workflow
if [ -f ".github/workflows/release.yml" ]; then
    if ! grep -q "strategy:" ".github/workflows/release.yml"; then
        validation_warning "Release workflow missing matrix strategy"
    fi
fi

log_success "CI/CD configuration validation complete"

# Check installation scripts
log_info "Checking installation scripts..."

if [ -f "scripts/install.sh" ]; then
    if [ ! -x "scripts/install.sh" ]; then
        validation_error "install.sh is not executable"
    fi
    
    # Check for required functions
    if ! grep -q "detect_platform" "scripts/install.sh"; then
        validation_warning "install.sh missing platform detection"
    fi
    if ! grep -q "get_latest_version" "scripts/install.sh"; then
        validation_warning "install.sh missing version detection"
    fi
fi

if [ -f "scripts/install.ps1" ]; then
    # Check PowerShell script structure
    if ! grep -q "param(" "scripts/install.ps1"; then
        validation_warning "install.ps1 missing parameter block"
    fi
fi

log_success "Installation scripts validation complete"

# Check documentation
log_info "Checking documentation..."

if [ -f "README.md" ]; then
    # Check for required sections
    if ! grep -q "Cross-Platform" "README.md"; then
        validation_warning "README.md missing cross-platform information"
    fi
    if ! grep -q "Installation" "README.md"; then
        validation_warning "README.md missing installation instructions"
    fi
    if ! grep -q "Usage" "README.md"; then
        validation_warning "README.md missing usage instructions"
    fi
fi

if [ -f "CONTRIBUTING.md" ]; then
    if ! grep -q "Platform-Specific" "CONTRIBUTING.md"; then
        validation_warning "CONTRIBUTING.md missing platform-specific guidelines"
    fi
fi

log_success "Documentation validation complete"

# Check Package.swift configuration
log_info "Checking Package.swift configuration..."

if [ -f "peekaboo-cli/Package.swift" ]; then
    # Check for platform support
    if ! grep -q "macOS" "peekaboo-cli/Package.swift"; then
        validation_error "Package.swift missing macOS platform"
    fi
    
    # Check for required dependencies
    if ! grep -q "swift-argument-parser" "peekaboo-cli/Package.swift"; then
        validation_error "Package.swift missing ArgumentParser dependency"
    fi
    
    # Check for platform-specific settings
    if ! grep -q "linkedFramework" "peekaboo-cli/Package.swift"; then
        validation_warning "Package.swift missing platform-specific frameworks"
    fi
fi

log_success "Package.swift validation complete"

# Check for security issues
log_info "Checking for potential security issues..."

# Check for hardcoded secrets or tokens (excluding legitimate API usage)
if grep -r -i "password.*=" peekaboo-cli/Sources/ --exclude-dir=.git 2>/dev/null | grep -v "NSLocalizedDescriptionKey" | grep -v "TOKEN_" > /dev/null; then
    validation_warning "Potential hardcoded secrets found - please review"
fi

# Check for TODO/FIXME comments that might indicate incomplete work
TODO_COUNT=$(grep -r -i "TODO\|FIXME\|XXX" peekaboo-cli/Sources/ --exclude-dir=.git 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    validation_warning "Found $TODO_COUNT TODO/FIXME comments - consider addressing before shipping"
fi

log_success "Security validation complete"

# Final validation summary
echo
echo "🎯 Validation Summary"
echo "===================="

if [ $VALIDATION_ERRORS -eq 0 ] && [ $VALIDATION_WARNINGS -eq 0 ]; then
    log_success "All validations passed! ✅"
    log_success "Project is ready for shipping! 🚀"
    exit 0
elif [ $VALIDATION_ERRORS -eq 0 ]; then
    log_warning "Validation completed with $VALIDATION_WARNINGS warning(s) ⚠️"
    log_info "Project is ready for shipping with minor issues to address"
    exit 0
else
    log_error "Validation failed with $VALIDATION_ERRORS error(s) and $VALIDATION_WARNINGS warning(s) ❌"
    log_error "Please fix the errors before shipping"
    exit 1
fi
