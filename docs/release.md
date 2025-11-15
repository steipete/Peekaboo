---
summary: 'Pre-release cleanup checklist for Peekaboo and all submodules'
read_when:
  - 'preparing for a release'
  - 'cleaning up repos before release'
---

# Release Cleanup Checklist

This checklist ensures all repositories (main repo and submodules) are clean, formatted, linted, tested, and committed before a release.

**Submodules:**
- `/AXorcist` - Accessibility automation library
- `/Commander` - Command-line argument parser
- `/Tachikoma` - AI/LLM integration framework

**Important:** Each repository (including submodules) has its own `CHANGELOG.md` that must be maintained independently.

## Pre-Release Cleanup Process

### 1. Format & Lint All Repositories

#### Main Repository (Peekaboo)
- [ ] Run SwiftFormat: `pnpm run format:swift` or `swift run swiftformat .`
- [ ] Run SwiftLint: `pnpm run lint:swift` or `swiftlint`
- [ ] Fix any linting errors or warnings
- [ ] Format TypeScript/JavaScript: `pnpm run format` (if applicable)
- [ ] Lint TypeScript/JavaScript: `pnpm run lint` (if applicable)

#### AXorcist Submodule
- [ ] `cd AXorcist`
- [ ] Run SwiftFormat: `swift run swiftformat .`
- [ ] Run SwiftLint: `swiftlint`
- [ ] Fix any linting errors or warnings
- [ ] `cd ..`

#### Commander Submodule
- [ ] `cd Commander`
- [ ] Run SwiftFormat: `swift run swiftformat .`
- [ ] Run SwiftLint: `swiftlint`
- [ ] Fix any linting errors or warnings
- [ ] `cd ..`

#### Tachikoma Submodule
- [ ] `cd Tachikoma`
- [ ] Run SwiftFormat: `swift run swiftformat .`
- [ ] Run SwiftLint: `swiftlint`
- [ ] Fix any linting errors or warnings
- [ ] `cd ..`

### 2. Run Tests in All Repositories

#### Main Repository (Peekaboo)
- [ ] Build Swift packages: `swift build`
- [ ] Run CI-compatible tests: `cd Apps/CLI && swift test`
- [ ] Run TypeScript tests (if applicable): `pnpm test`
- [ ] Verify all tests pass

#### AXorcist Submodule
- [ ] `cd AXorcist`
- [ ] Build: `swift build`
- [ ] Run tests: `swift test`
- [ ] Verify all tests pass
- [ ] `cd ..`

#### Commander Submodule
- [ ] `cd Commander`
- [ ] Build: `swift build`
- [ ] Run tests: `swift test`
- [ ] Verify all tests pass
- [ ] `cd ..`

#### Tachikoma Submodule
- [ ] `cd Tachikoma`
- [ ] Build: `swift build`
- [ ] Run tests: `swift test`
- [ ] Verify all tests pass
- [ ] `cd ..`

### 3. Update CHANGELOG.md Files

Review and update changelogs for each repository that has changes:

#### Main Repository (Peekaboo)
- [ ] Review `git log` since last release
- [ ] Check if `CHANGELOG.md` includes all recent changes
- [ ] Add missing entries following [Keep a Changelog](https://keepachangelog.com/) format
- [ ] Update version header and release date if needed

#### AXorcist Submodule
- [ ] `cd AXorcist`
- [ ] Review `git log` since last release
- [ ] Check if `AXorcist/CHANGELOG.md` includes all recent changes
- [ ] Add missing entries
- [ ] Update version header and release date if needed
- [ ] `cd ..`

#### Commander Submodule
- [ ] `cd Commander`
- [ ] Review `git log` since last release
- [ ] Check if `Commander/CHANGELOG.md` includes all recent changes
- [ ] Add missing entries
- [ ] Update version header and release date if needed
- [ ] `cd ..`

#### Tachikoma Submodule
- [ ] `cd Tachikoma`
- [ ] Review `git log` since last release
- [ ] Check if `Tachikoma/CHANGELOG.md` includes all recent changes
- [ ] Add missing entries
- [ ] Update version header and release date if needed
- [ ] `cd ..`

### 4. Commit Changes in Submodules

Commit changes in each submodule first, in logical groups using conventional commits.

#### AXorcist Submodule
- [ ] `cd AXorcist`
- [ ] Review changes: `git status`
- [ ] Group related files and commit:
  - [ ] Format/lint fixes: `git add <files> && git commit -m "style: apply format and lint fixes"`
  - [ ] Test updates: `git add <files> && git commit -m "test: update tests for release"`
  - [ ] CHANGELOG: `git add CHANGELOG.md && git commit -m "docs(changelog): add entries for vX.Y.Z"`
  - [ ] Other logical groups as needed
- [ ] Push: `git push`
- [ ] Verify no dirty files: `git status` should be clean
- [ ] `cd ..`

#### Commander Submodule
- [ ] `cd Commander`
- [ ] Review changes: `git status`
- [ ] Group related files and commit:
  - [ ] Format/lint fixes: `git add <files> && git commit -m "style: apply format and lint fixes"`
  - [ ] Test updates: `git add <files> && git commit -m "test: update tests for release"`
  - [ ] CHANGELOG: `git add CHANGELOG.md && git commit -m "docs(changelog): add entries for vX.Y.Z"`
  - [ ] Other logical groups as needed
- [ ] Push: `git push`
- [ ] Verify no dirty files: `git status` should be clean
- [ ] `cd ..`

#### Tachikoma Submodule
- [ ] `cd Tachikoma`
- [ ] Review changes: `git status`
- [ ] Group related files and commit:
  - [ ] Format/lint fixes: `git add <files> && git commit -m "style: apply format and lint fixes"`
  - [ ] Test updates: `git add <files> && git commit -m "test: update tests for release"`
  - [ ] CHANGELOG: `git add CHANGELOG.md && git commit -m "docs(changelog): add entries for vX.Y.Z"`
  - [ ] Other logical groups as needed
- [ ] Push: `git push`
- [ ] Verify no dirty files: `git status` should be clean
- [ ] `cd ..`

### 5. Commit Changes in Main Repository

Use `./scripts/committer` for all commits in the main repository:

- [ ] Review changes: `git status`
- [ ] Group related files and commit using the committer script:
  - [ ] Format/lint fixes: `./scripts/committer "style: apply format and lint fixes" "path/to/file1" "path/to/file2"`
  - [ ] Test updates: `./scripts/committer "test: update tests for release" "path/to/test1" "path/to/test2"`
  - [ ] CHANGELOG: `./scripts/committer "docs(changelog): add entries for vX.Y.Z" "CHANGELOG.md"`
  - [ ] Submodule updates: `./scripts/committer "chore: update submodule commits" "AXorcist" "Commander" "Tachikoma" "TauTUI"`
  - [ ] Other logical groups as needed
- [ ] Push: `./runner git push`
- [ ] Verify no dirty files: `git status` should be clean

### 6. Final Verification

Verify all repositories are clean and ready for release:

- [ ] Main repository: `git status` shows no uncommitted changes
- [ ] AXorcist: `cd AXorcist && git status` shows clean working tree
- [ ] Commander: `cd Commander && git status` shows clean working tree
- [ ] Tachikoma: `cd Tachikoma && git status` shows clean working tree
- [ ] TauTUI: `cd TauTUI && git status` shows clean working tree
- [ ] All tests passing across all repositories
- [ ] All submodules pushed to remote
- [ ] Main repository pushed to remote

## Quick Commands

```bash
# Check status of all repos at once
git status && \
  cd AXorcist && git status && cd .. && \
  cd Commander && git status && cd .. && \
  cd Tachikoma && git status && cd ..

# Format all repos (run from main repo root)
pnpm run format:swift && \
  (cd AXorcist && swift run swiftformat .) && \
  (cd Commander && swift run swiftformat .) && \
  (cd Tachikoma && swift run swiftformat .)

# Lint all repos (run from main repo root)
pnpm run lint:swift && \
  (cd AXorcist && swiftlint) && \
  (cd Commander && swiftlint) && \
  (cd Tachikoma && swiftlint)

# Build all repos (run from main repo root)
swift build && \
  (cd AXorcist && swift build) && \
  (cd Commander && swift build) && \
  (cd Tachikoma && swift build)

# Test all repos (run from main repo root)
(cd Apps/CLI && swift test) && \
  (cd AXorcist && swift test) && \
  (cd Commander && swift test) && \
  (cd Tachikoma && swift test)
```

## Notes

- **Conventional Commits**: Always use [Conventional Commits](https://www.conventionalcommits.org/) format: `type(scope): description`
- **Batch Related Changes**: Group related files into logical commits, don't commit files one at a time
- **Submodules First**: Always commit and push submodules before committing the main repository
- **Use Committer Script**: For main repo, use `./scripts/committer` to ensure proper staging
- **Native Git for Submodules**: Inside submodules, use native `git add/commit/push` (committer script only works for main repo)
- **CHANGELOG Format**: Follow [Keep a Changelog](https://keepachangelog.com/) format with sections: Added, Changed, Deprecated, Removed, Fixed, Security

## After Cleanup

Once all repositories are clean and committed, proceed to the full release process documented in [RELEASING.md](./RELEASING.md).
