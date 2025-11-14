---
summary: 'Review MCP Best Practices - May 26, 2025 guidance'
read_when:
  - 'planning work related to mcp best practices - may 26, 2025'
  - 'debugging or extending features described here'
---

# MCP Best Practices - May 26, 2025

**I. General Tool Configuration & Behavior**

1.  **Sensible Defaults:** All environment variables must have sensible defaults for easy out-of-the-box usage.
2.  **Dynamic Versioning:** The tool's version is emitted in its description. This version must be read dynamically (e.g., from `package.json`) and not hardcoded.
3.  **Tool & Parameter Descriptions:**
    *   **Tool Titles:** Use descriptive, human-friendly titles for tools.
    *   **Parameter Descriptions:** All parameters must offer a clear description.
    *   **Optional/Required Parameters:** Parameters must be explicitly noted as "optional" or "required."
    *   **Default Values:** If a parameter is optional, its default value must be explained.
    *   (These details should be verifiable by hovering over the tool in clients like Cursor or using the MCP inspector.)
4.  **Parameter Parsing:** Parameter parsing should be lenient (e.g., accept `path` if `project_path` is formally defined). Generally, advertise stricter schemas but be more lenient in execution to accommodate variations from agents.
5.  **Runtime Error Handling:** In case of an error, emit a helpful message to the caller with information to potentially recover.
6.  **Configuration Error Handling:** Misconfigurations (e.g., wrongly set environment variables) must not crash the tool. Instead, provide a useful explanation when the tool is run, enabling the user to self-correct their setup.
7.  **Output Control:** There should be no output to `stdio` during normal tool operation, as this can disrupt MCP clients. File-based logging is the designated method for operational output.
8.  **`info` Command:**
    *   At least one tool must offer an `info` sub command (find the most appropriate tool and add there)
    *   This command shall list:
        *   The version of the MCP tool.
        *   The status of any required native dependencies (if applicable), including tests for their presence and functionality.
        *   Any detected configuration issues or missing environment variables (e.g., problems with the logger path).

**II. Logging (Pino)**

1.  **Default File Logger:** Pino is used for logging with a default file logger in the system's log directory (e.g., `~/Library/Logs/`). The log file path is configurable via the `[ProjectName]_LOG_FILE` environment variable.
2.  **Log Path Resilience:**
    *   Pino logic must automatically create missing parent directories for the specified log file path.
    *   If pino cannot write to the `[ProjectName]_LOG_FILE` path, it must fall back to logging to the default temporary directory path.
3.  **Configurable Log Level:** The log level is set using the `[ProjectName]_LOG_LEVEL` environment variable (accepts upper, lower, or mixed case values).
4.  **Optional Console Logging:** An environment variable, `[ProjectName]_CONSOLE_LOGGING=true`, enables logging to the console in addition to the pino file logger.
5.  **Logger Flush:** The logger must be flushed before the process exits to ensure all log messages are written.

**III. Code, Dependencies & Build**

1.  **Dependency Management:** All dependencies should be kept at their latest stable versions. (The release script will warn for outdated dependencies).
2.  **Static Analysis:** There must be no linter (e.g., ESLint) or TypeScript errors.
3.  **File Size:** No single file should exceed 500 lines of code (LOC); aim for below 300 LOC.
4.  **Execution with Compiled Code:** The startup logic and all tool operations must always use the compiled JavaScript output (e.g., from the `dist` folder).
5.  **Shebangs:** Compiled JavaScript files intended for direct execution must have the correct shebang (e.g., `#!/usr/bin/env node`).
6.  **NPM Package Contents:** The published npm package must contain only the absolute minimum files: the `dist/` folder, any potential native components, the `README.md`, and a `LICENSE` file.

**IV. Testing**

1.  **Test Framework:** Tests must use `vitest`.
2.  **TypeScript Test Suite:** A comprehensive test suite for the TypeScript layer is required.
3.  **End-to-End (E2E) Tests:** E2E tests that validate the complete setup are necessary. (These might be run as release preparation if CI execution is challenging due to permissions like macOS access).
4.  **NPM Scripts:**
    *   `npm run prepare-release` executes a comprehensive test suite (detailed in Section VI).
    *   `npm run inspector` executes `npx @modelcontextprotocol/inspector node path/to/server/index.js`.

**V. Native Binary Rules (If Applicable)**

1.  **macOS Compatibility:** The binary must be universal (Apple Silicon & Intel) and support the current macOS version and the previous major version (n-1, e.g., macOS >= 14 if current is 15).
2.  **Build Optimization:** Compiler and linker flags must be set to achieve a minimal binary file size.
3.  **Native Test Suite:** A comprehensive test suite using Swift's native testing tools (e.g., `swift-test` or XCTest) is required.
4.  **Custom Path Configuration:** An environment variable must allow setting a custom absolute path to run the native binary.
5.  **Error Communication:** If the tool uses a native library, `errno` (or an equivalent mechanism) must be used to pass error and execution issues to the TypeScript logger and back to the tool.
6.  **Version Synchronization:** The native CLI and the MCP tool (TypeScript package) must have the same version number. This version must be injected during the build process, not hardcoded, while still allowing easy development (e.g., in Xcode using current source, with the script replacing the version on build).
7.  **Native Code Quality:**
    *   The CLI must have no linter issues (e.g., SwiftLint for Swift).
    *   A formatter must be applied (e.g., SwiftFormat for Swift).
    *   The CLI must show no analyzer issues.
8.  **JSON Communication:** The native binary part of the tool must have a mode to communicate in JSON back to the TypeScript server for easier parsing. JSON responses should include debug logs if requested (e.g., by passing a log level).
9.  **CLI Help Command:** The binary must respond to `--help` with a helpful command explaining its use and all options.
10. **Argument Parsing Framework:** The binary must use a robust argument parser framework (e.g., our in-repo `Commander` module for Swift).
11. **Single File Distribution:** For native CLIs, consider options for distributing as a single, statically linked binary if feasible and beneficial for simpler installation by end-users who might use the CLI directly.

**VI. Rules to Check Before a Release (`scripts/prepare-release.js`)**

*   There is a `scripts/prepare-release.js` that runs an extensive test suite. The script runs these checks sequentially and stops at the first failure.

    **Git & Version Control:**
    1.  Check current branch (warns if not on main or designated release branch).
    2.  Check for uncommitted changes.
    3.  Check if synced with origin/main (or designated release branch).
    4.  Version availability check (ensures version isn't already published).
    5.  Version consistency between `package.json` and `package-lock.json`.
    6.  **Changelog Check:** Check for a changelog entry corresponding to the current version.

    **Code Quality & Security:**
    1.  Dependency installation check.
    2.  Outdated dependencies check (warning only).
    3.  Security audit (fails on critical/high vulnerabilities).
    4.  TypeScript compilation.
    5.  TypeScript tests.
    6.  TypeScript declaration files generation.
    7.  Delete any build folders and reset package caches before building.
    8.  *If native binary exists:* Swift analyze.
    9.  *If native binary exists:* Swift formatting (SwiftFormat).
    10. *If native binary exists:* Swift linting (SwiftLint).
    11. *If native binary exists:* Swift tests.
    12. No build warnings.

    **Binary & CLI Validation (If Applicable):**
    13. *If native binary exists:* Swift CLI command tests (help, version, and other key functionalities).
    14. *If native binary exists:* Swift CLI error handling tests (invalid commands, missing args, invalid window index, etc.).
    15. *If native binary exists:* Swift CLI JSON output validation.
    16. *If native binary exists:* Binary exists and is executable.
    17. *If native binary exists:* Binary contains both architectures (arm64 + x86_64, verifiable via `lipo -info`).
    18. *If native binary exists:* Binary responds correctly to `--help`.

    **Package Validation:**
    19. Required fields in `package.json`.
    20. Package size check (warns if >2MB, configurable threshold).
    21. Executable permission check in `postinstall` (if a CLI is present).
    22. Critical files included (e.g., `dist/index.js`, native binary name, `README.md`, `LICENSE`).
    23. MCP server smoke test (JSON-RPC request/response).
    24. Full integration tests.

*   Releases are first done with a `beta` tag to the npm registry so they can be tested via the `npx [packageName]@beta install` method.
