import Foundation

/// Check if the CLI binary is stale compared to the current git state.
/// Only runs in debug builds when git config 'peekaboo.check-build-staleness' is true.
func checkBuildStaleness() {
    // Check if staleness checking is enabled via git config
    let configCheck = Process()
    configCheck.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    configCheck.arguments = ["config", "peekaboo.check-build-staleness"]

    let configPipe = Pipe()
    configCheck.standardOutput = configPipe
    configCheck.standardError = Pipe() // Silence stderr

    do {
        try configCheck.run()
        configCheck.waitUntilExit()

        // Only proceed if the config value is "true"
        let configData = configPipe.fileHandleForReading.readDataToEndOfFile()
        let configValue = String(data: configData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard configValue == "true" else {
            return // Staleness checking is disabled
        }
    } catch {
        return // Git config command failed, skip check
    }

    // Check 1: Git commit comparison
    checkGitCommitStaleness()

    // Check 2: File modification time comparison
    checkFileModificationStaleness()
}

/// Check if the embedded git commit differs from the current git commit
private func checkGitCommitStaleness() {
    // Get current git commit hash
    let gitProcess = Process()
    gitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    gitProcess.arguments = ["rev-parse", "--short", "HEAD"]

    let gitPipe = Pipe()
    gitProcess.standardOutput = gitPipe
    gitProcess.standardError = Pipe() // Silence stderr

    do {
        try gitProcess.run()
        gitProcess.waitUntilExit()

        guard gitProcess.terminationStatus == 0 else {
            return // Git command failed, skip check
        }

        let gitData = gitPipe.fileHandleForReading.readDataToEndOfFile()
        let rawCommitString = String(data: gitData, encoding: .utf8)
        let currentCommit = rawCommitString?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Get embedded commit from build (strip -dirty suffix if present)
        let embeddedCommit = Version.gitCommit.replacingOccurrences(of: "-dirty", with: "")

        // Compare commits
        if !currentCommit.isEmpty && currentCommit != embeddedCommit {
            logError("❌ CLI binary is outdated and needs to be rebuilt!")
            logError("   Built with commit: \(embeddedCommit)")
            logError("   Current commit:    \(currentCommit)")
            logError("")
            logError("   Run ./scripts/build-swift-debug.sh to rebuild")
            exit(1)
        }
    } catch {
        return // Git command failed, skip check
    }
}

/// Check if any tracked files have been modified after the build time
private func checkFileModificationStaleness() {
    // Parse build date from Version.buildDate (ISO 8601 format)
    let dateFormatter = ISO8601DateFormatter()
    guard let buildDate = dateFormatter.date(from: Version.buildDate) else {
        return // Could not parse build date, skip check
    }

    // Get git repository root
    guard let gitRoot = getGitRepositoryRoot() else {
        return // Could not determine git root, skip check
    }

    // Get list of modified files from git status
    let gitStatusProcess = Process()
    gitStatusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    gitStatusProcess.arguments = ["status", "--porcelain=1"]

    let statusPipe = Pipe()
    gitStatusProcess.standardOutput = statusPipe
    gitStatusProcess.standardError = Pipe() // Silence stderr

    do {
        try gitStatusProcess.run()
        gitStatusProcess.waitUntilExit()

        guard gitStatusProcess.terminationStatus == 0 else {
            return // Git command failed, skip check
        }

        let statusData = statusPipe.fileHandleForReading.readDataToEndOfFile()
        let statusOutput = String(data: statusData, encoding: .utf8) ?? ""

        // Parse git status output
        let modifiedFiles = parseGitStatusOutput(statusOutput)

        // Check each modified file's modification time
        for filePath in modifiedFiles where
            isFileNewerThanBuild(filePath: filePath, buildDate: buildDate, gitRoot: gitRoot)
        {
            logError("❌ CLI binary is outdated and needs to be rebuilt!")
            logError("   Build time:     \(Version.buildDate)")
            logError("   Modified file:  \(filePath)")
            logError("")
            logError("   Run ./scripts/build-swift-debug.sh to rebuild")
            exit(1)
        }
    } catch {
        return // Git command failed, skip check
    }
}

/// Parse git status --porcelain=1 output to extract file paths
/// Format: "XY filename" or "XY orig_path -> new_path" for renames
private func parseGitStatusOutput(_ output: String) -> [String] {
    // Parse git status --porcelain=1 output to extract file paths
    let lines = output.components(separatedBy: .newlines)
    var filePaths: [String] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }

        // Git status format: "XY filename" or "XY orig_path -> new_path"
        // X = staged status, Y = working tree status
        guard trimmed.count >= 3 else { continue }

        let statusCodes = String(trimmed.prefix(2))
        var filePath = String(trimmed.dropFirst(2)) // Skip "XY"

        // Remove leading space if present
        if filePath.hasPrefix(" ") {
            filePath = String(filePath.dropFirst())
        }

        // Include files that are modified (M), added (A), or have other changes
        // Skip deleted files (D) since they can't be newer than build
        if statusCodes.contains("M") || statusCodes.contains("A") || statusCodes.contains("R") || statusCodes
            .contains("C") || statusCodes.contains("U") {
            // Handle renamed files: "orig_path -> new_path"
            // For renames, we want to check the new path
            if filePath.contains(" -> ") {
                let components = filePath.components(separatedBy: " -> ")
                if components.count == 2 {
                    filePath = components[1] // Use the new path
                }
            }

            // Handle quoted paths (git quotes paths with special characters)
            let cleanPath = filePath.hasPrefix("\"") && filePath.hasSuffix("\"")
                ? String(filePath.dropFirst().dropLast())
                : filePath
            filePaths.append(cleanPath)
        }
    }

    return filePaths
}

/// Get the git repository root directory
private func getGitRepositoryRoot() -> String? {
    // Get the git repository root directory
    let gitProcess = Process()
    gitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    gitProcess.arguments = ["rev-parse", "--show-toplevel"]

    let pipe = Pipe()
    gitProcess.standardOutput = pipe
    gitProcess.standardError = Pipe() // Silence stderr

    do {
        try gitProcess.run()
        gitProcess.waitUntilExit()

        guard gitProcess.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check if output is empty after trimming
        guard let output, !output.isEmpty else {
            return nil
        }
        return output
    } catch {
        return nil
    }
}

/// Check if a file's modification time is newer than the build date
private func isFileNewerThanBuild(filePath: String, buildDate: Date, gitRoot: String) -> Bool {
    // Check if a file's modification time is newer than the build date
    let fileManager = FileManager.default
    // Git status paths are relative to repository root, not current directory
    let fullPath = (filePath.hasPrefix("/")) ? filePath : "\(gitRoot)/\(filePath)"

    do {
        let attributes = try fileManager.attributesOfItem(atPath: fullPath)
        if let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate > buildDate
        }
    } catch {
        // File might not exist or be accessible, skip this check
        return false
    }

    return false
}
