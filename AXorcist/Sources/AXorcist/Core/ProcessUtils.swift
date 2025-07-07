// ProcessUtils.swift - Utilities for process and application inspection.

import AppKit // For NSRunningApplication, NSWorkspace
import Foundation

// GlobalAXLogger is assumed to be available

public func pid(forAppIdentifier ident: String) -> pid_t? {
    axDebugLog(
        "ProcessUtils: Attempting to find PID for identifier: '\(ident)'",
        file: #file,
        function: #function,
        line: #line
    )

    // Check if identifier is "focused"
    if let pid = pidForFocusedApp(ident) {
        return pid
    }

    // Try by bundle identifier
    if let pid = pidByBundleIdentifier(ident) {
        return pid
    }

    // Try by localized name
    if let pid = pidByLocalizedName(ident) {
        return pid
    }

    // Try by path
    if let pid = pidByPath(ident) {
        return pid
    }

    // Try interpreting as PID string
    if let pid = pidByPIDString(ident) {
        return pid
    }

    axWarningLog(
        "ProcessUtils: PID not found for identifier: '\(ident)'",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

private func pidForFocusedApp(_ ident: String) -> pid_t? {
    guard ident == "focused" else { return nil }

    axDebugLog(
        "ProcessUtils: Identifier is 'focused'. Checking frontmost application.",
        file: #file,
        function: #function,
        line: #line
    )

    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        axDebugLog(
            "ProcessUtils: Frontmost app is '\(frontmostApp.localizedName ?? "nil")' " +
                "(PID: \(frontmostApp.processIdentifier), BundleID: \(frontmostApp.bundleIdentifier ?? "nil"), " +
                "Terminated: \(frontmostApp.isTerminated))",
            file: #file,
            function: #function,
            line: #line
        )
        return frontmostApp.processIdentifier
    } else {
        axWarningLog(
            "ProcessUtils: NSWorkspace.shared.frontmostApplication returned nil.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }
}

private func pidByBundleIdentifier(_ ident: String) -> pid_t? {
    axDebugLog(
        "ProcessUtils: Trying by bundle identifier '\(ident)'.",
        file: #file,
        function: #function,
        line: #line
    )

    let appsByBundleID = NSRunningApplication.runningApplications(withBundleIdentifier: ident)
    guard !appsByBundleID.isEmpty else {
        axDebugLog(
            "ProcessUtils: No applications found for bundle identifier '\(ident)'.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }

    axDebugLog(
        "ProcessUtils: Found \(appsByBundleID.count) app(s) by bundle ID '\(ident)'.",
        file: #file,
        function: #function,
        line: #line
    )

    logRunningApplications(appsByBundleID)

    if let app = appsByBundleID.first(where: { !$0.isTerminated }) {
        axDebugLog(
            "ProcessUtils: Using first non-terminated app found by bundle ID: " +
                "'\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier))",
            file: #file,
            function: #function,
            line: #line
        )
        return app.processIdentifier
    } else {
        axDebugLog(
            "ProcessUtils: All apps found by bundle ID '\(ident)' are terminated.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }
}

private func pidByLocalizedName(_ ident: String) -> pid_t? {
    axDebugLog(
        "ProcessUtils: Trying by localized name (case-insensitive) '\(ident)'.",
        file: #file,
        function: #function,
        line: #line
    )

    let allApps = NSWorkspace.shared.runningApplications
    axDebugLog(
        "ProcessUtils: pidByLocalizedName - NSWorkspace.shared.runningApplications returned \(allApps.count) total apps.",
        file: #file, function: #function, line: #line
    )

    for (idx, app) in allApps.enumerated() {
        axDebugLog(
            "ProcessUtils: pidByLocalizedName - Checking app [\(idx)]: " +
                "'\(app.localizedName ?? "NIL_NAME")' (Terminated: \(app.isTerminated), " +
                "BundleID: \(app.bundleIdentifier ?? "NIL_BID")) against target '\(ident)'.",
            file: #file, function: #function, line: #line
        )
        if !app.isTerminated, app.localizedName?.lowercased() == ident.lowercased() {
            axDebugLog(
                "ProcessUtils: Found non-terminated app by localized name (in loop): " +
                    "'\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier), " +
                    "BundleID: '\(app.bundleIdentifier ?? "nil")')",
                file: #file,
                function: #function,
                line: #line
            )
            return app.processIdentifier
        }
    }

    axDebugLog(
        "ProcessUtils: No non-terminated app found matching localized name '\(ident)' in the loop. Original filter logic will be skipped as redundant.",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

private func pidByPath(_ ident: String) -> pid_t? {
    axDebugLog(
        "ProcessUtils: Trying by path '\(ident)'.",
        file: #file,
        function: #function,
        line: #line
    )

    let potentialPath = (ident as NSString).expandingTildeInPath
    guard FileManager.default.fileExists(atPath: potentialPath),
          let bundle = Bundle(path: potentialPath),
          let bundleId = bundle.bundleIdentifier
    else {
        axDebugLog(
            "ProcessUtils: Identifier '\(ident)' is not a valid file path or bundle info could not be read.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }

    axDebugLog(
        "ProcessUtils: Path '\(potentialPath)' resolved to bundle '\(bundleId)'. " +
            "Looking up running apps with this bundle ID.",
        file: #file,
        function: #function,
        line: #line
    )

    return pidForResolvedBundleID(bundleId, fromPath: potentialPath)
}

private func pidForResolvedBundleID(_ bundleId: String, fromPath path: String) -> pid_t? {
    let appsByResolvedBundleID = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    guard !appsByResolvedBundleID.isEmpty else {
        axDebugLog(
            "ProcessUtils: No running applications found for bundle identifier '\(bundleId)' " +
                "derived from path '\(path)'.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }

    axDebugLog(
        "ProcessUtils: Found \(appsByResolvedBundleID.count) app(s) by resolved bundle ID '\(bundleId)'.",
        file: #file,
        function: #function,
        line: #line
    )

    logRunningApplications(appsByResolvedBundleID, context: "from path")

    if let app = appsByResolvedBundleID.first(where: { !$0.isTerminated }) {
        axDebugLog(
            "ProcessUtils: Using first non-terminated app found by path " +
                "(via bundle ID '\(bundleId)'): '\(app.localizedName ?? "nil")' " +
                "(PID: \(app.processIdentifier))",
            file: #file,
            function: #function,
            line: #line
        )
        return app.processIdentifier
    } else {
        axDebugLog(
            "ProcessUtils: All apps for bundle ID '\(bundleId)' (from path) are terminated.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }
}

private func pidByPIDString(_ ident: String) -> pid_t? {
    axDebugLog(
        "ProcessUtils: Trying by interpreting '\(ident)' as a PID string.",
        file: #file,
        function: #function,
        line: #line
    )

    guard let pidInt = Int32(ident) else { return nil }

    if let appByPid = NSRunningApplication(processIdentifier: pidInt),
       !appByPid.isTerminated
    {
        axDebugLog(
            "ProcessUtils: Found non-terminated app by PID string '\(ident)': " +
                "'\(appByPid.localizedName ?? "nil")' " +
                "(PID: \(appByPid.processIdentifier), " +
                "BundleID: '\(appByPid.bundleIdentifier ?? "nil")')",
            file: #file, function: #function, line: #line
        )
        return pidInt
    } else {
        if NSRunningApplication(processIdentifier: pidInt)?.isTerminated == true {
            axDebugLog(
                "ProcessUtils: String '\(ident)' is a PID, but the app is terminated.",
                file: #file, function: #function, line: #line
            )
        } else {
            axDebugLog(
                "ProcessUtils: String '\(ident)' looked like a PID but " +
                    "no running application found for it.",
                file: #file,
                function: #function,
                line: #line
            )
        }
        return nil
    }
}

private func logRunningApplications(_ apps: [NSRunningApplication], context: String = "") {
    let contextPrefix = context.isEmpty ? "" : " \(context)"
    for (index, application) in apps.enumerated() {
        axDebugLog(
            "ProcessUtils: App [\(index)]\(contextPrefix) - Name: '\(application.localizedName ?? "nil")', " +
                "PID: \(application.processIdentifier), " +
                "BundleID: '\(application.bundleIdentifier ?? "nil")', " +
                "Terminated: \(application.isTerminated)",
            file: #file, function: #function, line: #line
        )
    }
}

func findFrontmostApplicationPid() -> pid_t? {
    axDebugLog(
        "ProcessUtils: findFrontmostApplicationPid called.",
        file: #file,
        function: #function,
        line: #line
    )
    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        axDebugLog(
            "ProcessUtils: Frontmost app for findFrontmostApplicationPid is " +
                "'\(frontmostApp.localizedName ?? "nil")' " +
                "(PID: \(frontmostApp.processIdentifier), " +
                "BundleID: \(frontmostApp.bundleIdentifier ?? "nil")', " +
                "Terminated: \(frontmostApp.isTerminated))",
            file: #file, function: #function, line: #line
        )
        return frontmostApp.processIdentifier
    } else {
        axWarningLog(
            "ProcessUtils: NSWorkspace.shared.frontmostApplication " +
                "returned nil in findFrontmostApplicationPid.",
            file: #file,
            function: #function,
            line: #line
        )
        return nil
    }
}

public func getParentProcessName() -> String? {
    let parentPid = getppid()
    axDebugLog(
        "ProcessUtils: Parent PID is \(parentPid).",
        file: #file,
        function: #function,
        line: #line
    )
    if let parentApp = NSRunningApplication(processIdentifier: parentPid) {
        axDebugLog(
            "ProcessUtils: Parent app is '\(parentApp.localizedName ?? "nil")' " +
                "(BundleID: '\(parentApp.bundleIdentifier ?? "nil")')",
            file: #file,
            function: #function,
            line: #line
        )
        return parentApp.localizedName ?? parentApp.bundleIdentifier
    }
    axWarningLog(
        "ProcessUtils: Could not get NSRunningApplication for parent PID \(parentPid).",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}
