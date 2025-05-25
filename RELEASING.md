# Releasing Peekaboo MCP

This document outlines the steps to release a new version of the `@steipete/peekaboo-mcp` NPM package.

## Pre-Release Checklist

1.  **Ensure Main Branch is Up-to-Date:**
    - Pull the latest changes from the main branch (`main` or `master`).
    - `git pull origin main`

2.  **Create a Release Branch (Optional but Recommended):**
    - Create a new branch for the release, e.g., `release/v1.0.0-beta.3`.
    - `git checkout -b release/vX.Y.Z`

3.  **Update Version Number:**
    - Decide on the new semantic version number (e.g., `1.0.0-beta.3`, `1.0.0`, `1.1.0`).
    - Update the `version` field in `package.json`.

4.  **Update Documentation:**
    - **`README.md`**: Ensure it accurately reflects the latest features, installation instructions, and any breaking changes.
    - **`docs/spec.md`**: If there are changes to tool schemas or server behavior, update the detailed specification.
    - Any other relevant documentation.

5.  **Update `CHANGELOG.md`:**
    - Add a new section for the upcoming release version (e.g., `## [1.0.0-beta.3] - YYYY-MM-DD`).
    - List all notable changes (Added, Changed, Fixed, Removed, Deprecated, Security) under this version.
    - Replace `YYYY-MM-DD` with the current date.

6.  **Run All Tests:**
    - Ensure all unit, integration, and E2E tests are passing.
    - `npm test` (or `npm run test:all` if that's more comprehensive for your setup).

7.  **Build the Project:**
    - Run the build script to compile TypeScript and the Swift CLI.
    - `npm run build:all` (as defined in `package.json`).

8.  **Commit Changes:**
    - Commit all changes related to the version bump, documentation, and changelog.
    - `git add .`
    - `git commit -m "Prepare release vX.Y.Z"`

9.  **Merge to Main Branch (If Using a Release Branch):**
    - Merge the release branch back into the main branch.
    - `git checkout main`
    - `git merge release/vX.Y.Z --no-ff` (using `--no-ff` creates a merge commit, which can be useful for tracking releases).
    - `git push origin main`

## Publishing to NPM

1.  **NPM Publish Dry Run:**
    - This step is crucial to verify what files will be included in the package without actually publishing.
    - `npm publish --access public --tag <your_tag> --dry-run`
        - Replace `<your_tag>` with the appropriate tag (e.g., `beta`, `latest`). For pre-releases, always use a specific tag like `beta` or `rc`.
        - `--access public` is needed for scoped packages if they are intended to be public.
    - Carefully review the list of files. Ensure it includes `dist/`, `peekaboo` (the Swift binary), `package.json`, `README.md`, `CHANGELOG.md`, and `LICENSE`. Ensure no unnecessary files are included.

2.  **Actual NPM Publish:**
    - If the dry run is satisfactory, proceed with the actual publish command.
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