# Releasing Peekaboo MCP

This document outlines the steps to release a new version of the `@steipete/peekaboo-mcp` NPM package.

## Automated Release Preparation

The project includes an automated release preparation script that performs comprehensive checks before release. Run it with:

```bash
npm run prepare-release
```

This script performs the following checks:
- **Git Status**: Ensures you're on the main branch with no uncommitted changes
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

If all checks pass, follow the manual steps below.

## Manual Pre-Release Steps

1.  **Update Version Number:**
    - Decide on the new semantic version number (e.g., `1.0.0-beta.3`, `1.0.0`, `1.1.0`).
    - Update the `version` field in `package.json`.

2.  **Update Documentation:**
    - **`README.md`**: Ensure it accurately reflects the latest features, installation instructions, and any breaking changes.
    - **`docs/spec.md`**: If there are changes to tool schemas or server behavior, update the detailed specification.
    - Any other relevant documentation.

3.  **Update `CHANGELOG.md`:**
    - Add a new section for the upcoming release version (e.g., `## [1.0.0-beta.3] - YYYY-MM-DD`).
    - List all notable changes (Added, Changed, Fixed, Removed, Deprecated, Security) under this version.
    - Replace `YYYY-MM-DD` with the current date.

4.  **Run Release Preparation:**
    - Run `npm run prepare-release` to ensure everything is ready.
    - Fix any issues identified by the script.

5.  **Commit Changes:**
    - Commit all changes related to the version bump, documentation, and changelog.
    - `git add .`
    - `git commit -m "Prepare release vX.Y.Z"`

## Publishing to NPM

1.  **NPM Publish Dry Run:**
    - This step is crucial to verify what files will be included in the package without actually publishing.
    - `npm publish --access public --tag <your_tag> --dry-run`
        - Replace `<your_tag>` with the appropriate tag (e.g., `beta`, `latest`). For pre-releases, always use a specific tag like `beta` or `rc`.
        - `--access public` is needed for scoped packages if they are intended to be public.
    - Carefully review the list of files. Ensure it includes `dist/`, `peekaboo` (the Swift binary), `package.json`, `README.md`, `CHANGELOG.md`, and `LICENSE`. Ensure no unnecessary files are included.

2.  **Actual NPM Publish:**
    - If the dry run is satisfactory, proceed with the actual publish command.
    - Use tag "beta" if the version is a beta, else omit tag to do a release version.
    - `npm publish --access public --tag <your_tag>`

## Post-Publish Steps

1.  **Create a Git Tag:**
    - Create a Git tag for the new version.
    - `git tag vX.Y.Z` (e.g., `git tag v1.0.0-beta.3`)

2.  **Push the Git Tag:**
    - Push the tag to the remote repository.
    - `git push origin vX.Y.Z`

3.  **Create a GitHub Release (Optional):**
    - Go to the GitHub repository's "Releases" section.
    - Draft a new release, selecting the tag you just pushed.
    - Copy the relevant section from `CHANGELOG.md` into the release description.
    - You can also attach any build artifacts (like the `peekaboo` binary or the `.tgz` NPM package) to the GitHub release for direct download if desired.

4.  **Announce the Release (Optional):**
    - Announce the new release on relevant channels (e.g., team chat, Twitter, project website).

---

**Note on `prepublishOnly`:** The `package.json` contains a `prepublishOnly` script that runs `npm run build:all`. This ensures that the project is always built before publishing. 