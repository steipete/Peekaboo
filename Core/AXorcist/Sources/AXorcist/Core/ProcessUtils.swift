// ProcessUtils.swift - Utilities for process and application inspection.

import AppKit // For NSRunningApplication, NSWorkspace
import Foundation

@inline(__always)
private func processDebugLog(
    _ parts: String...,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line
) {
    axDebugLog(
        logSegments(parts),
        file: String(describing: file),
        function: String(describing: function),
        line: Int(line)
    )
}

@inline(__always)
private func processWarningLog(
    _ parts: String...,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line
) {
    axWarningLog(
        logSegments(parts),
        file: String(describing: file),
        function: String(describing: function),
        line: Int(line)
    )
}

// GlobalAXLogger is assumed to be available

public func pid(forAppIdentifier ident: String) -> pid_t? {
    processDebugLog("ProcessUtils: Attempting to find PID for identifier: '\(ident)'")

    let strategies: [() -> pid_t?] = [
        { pidForFocusedApp(ident) },
        { pidByBundleIdentifier(ident) },
        { pidByLocalizedName(ident) },
        { pidByPath(ident) },
        { pidByPIDString(ident) }
    ]

    for strategy in strategies {
        if let pid = strategy() {
            return pid
        }
    }

    processWarningLog("ProcessUtils: PID not found for identifier: '\(ident)'")
    return nil
}

private func pidForFocusedApp(_ ident: String) -> pid_t? {
    guard ident == "focused" else { return nil }

    processDebugLog("ProcessUtils: Identifier is 'focused'.", "Checking frontmost application.")

    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        processDebugLog(
            "ProcessUtils: Frontmost app is '\(frontmostApp.localizedName ?? "nil")'",
            "PID: \(frontmostApp.processIdentifier)",
            "BundleID: \(frontmostApp.bundleIdentifier ?? "nil")",
            "Terminated: \(frontmostApp.isTerminated)"
        )
        return frontmostApp.processIdentifier
    } else {
        processWarningLog("ProcessUtils: NSWorkspace.shared.frontmostApplication returned nil.")
        return nil
    }
}

private func pidByBundleIdentifier(_ ident: String) -> pid_t? {
    processDebugLog("ProcessUtils: Trying by bundle identifier '\(ident)'.")

    let appsByBundleID = NSRunningApplication.runningApplications(withBundleIdentifier: ident)
    guard !appsByBundleID.isEmpty else {
        processDebugLog("ProcessUtils: No applications found for bundle identifier '\(ident)'.")
        return nil
    }

    processDebugLog("ProcessUtils: Found \(appsByBundleID.count) app(s) by bundle ID '\(ident)'.")

    logRunningApplications(appsByBundleID)

    if let app = appsByBundleID.first(where: { !$0.isTerminated }) {
        processDebugLog(
            "ProcessUtils: Using first non-terminated app found by bundle ID",
            "'\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier))"
        )
        return app.processIdentifier
    } else {
        processDebugLog("ProcessUtils: All apps found by bundle ID '\(ident)' are terminated.")
        return nil
    }
}

private func pidByLocalizedName(_ ident: String) -> pid_t? {
    processDebugLog("ProcessUtils: Trying by localized name (case-insensitive) '\(ident)'.")

    let allApps = NSWorkspace.shared.runningApplications
    processDebugLog(
        "ProcessUtils: pidByLocalizedName - NSWorkspace.shared.runningApplications returned",
        "\(allApps.count) total apps."
    )

    for (idx, app) in allApps.enumerated() {
        processDebugLog(
            "ProcessUtils: pidByLocalizedName - Checking app [\(idx)]",
            "'\(app.localizedName ?? "NIL_NAME")' (Terminated: \(app.isTerminated))",
            "BundleID: \(app.bundleIdentifier ?? "NIL_BID") against target '\(ident)'"
        )
        if !app.isTerminated, app.localizedName?.lowercased() == ident.lowercased() {
            processDebugLog(
                "ProcessUtils: Found non-terminated app by localized name (in loop)",
                "'\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier))",
                "BundleID: '\(app.bundleIdentifier ?? "nil")'"
            )
            return app.processIdentifier
        }
    }

    processDebugLog(
        "ProcessUtils: No non-terminated app found matching localized name '\(ident)'",
        "Original filter logic skipped as redundant"
    )
    return nil
}

private func pidByPath(_ ident: String) -> pid_t? {
    processDebugLog("ProcessUtils: Trying by path '\(ident)'.")

    let potentialPath = (ident as NSString).expandingTildeInPath
    guard FileManager.default.fileExists(atPath: potentialPath),
          let bundle = Bundle(path: potentialPath),
          let bundleId = bundle.bundleIdentifier
    else {
        processDebugLog(
            "ProcessUtils: Identifier '\(ident)' is not a valid file path",
            "Bundle info could not be read"
        )
        return nil
    }

    processDebugLog(
        "ProcessUtils: Path '\(potentialPath)' resolved to bundle '\(bundleId)'",
        "Looking up running apps with this bundle ID"
    )

    return pidForResolvedBundleID(bundleId, fromPath: potentialPath)
}

private func pidByPIDString(_ ident: String) -> pid_t? {
    processDebugLog("ProcessUtils: Trying by interpreting '\(ident)' as a PID string.")

    guard let pidInt = Int32(ident) else { return nil }

    if let appByPid = NSRunningApplication(processIdentifier: pidInt),
       !appByPid.isTerminated
    {
        processDebugLog(
            "ProcessUtils: Found non-terminated app by PID string '\(ident)'",
            "'\(appByPid.localizedName ?? "nil")'",
            "PID: \(appByPid.processIdentifier)",
            "BundleID: '\(appByPid.bundleIdentifier ?? "nil")'"
        )
        return pidInt
    } else {
        if NSRunningApplication(processIdentifier: pidInt)?.isTerminated == true {
            processDebugLog("ProcessUtils: String '\(ident)' is a PID, but the app is terminated.")
        } else {
            processDebugLog(
                "ProcessUtils: String '\(ident)' looked like a PID",
                "but no running application found for it."
            )
        }
        return nil
    }
}

private func logRunningApplications(_ apps: [NSRunningApplication], context: String = "") {
    let contextPrefix = context.isEmpty ? "" : " \(context)"
    for (index, application) in apps.enumerated() {
        processDebugLog(
            "ProcessUtils: App [\(index)]\(contextPrefix) - Name: '\(application.localizedName ?? "nil")'",
            "PID: \(application.processIdentifier)",
            "BundleID: '\(application.bundleIdentifier ?? "nil")'",
            "Terminated: \(application.isTerminated)"
        )
    }
}

private func pidForResolvedBundleID(_ bundleID: String, fromPath path: String) -> pid_t? {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    guard !apps.isEmpty else {
        processDebugLog(
            "ProcessUtils: No running apps match resolved bundle '\(bundleID)' from path '\(path)'")
        return nil
    }

    logRunningApplications(apps, context: "resolved bundle lookup")

    if let activeApp = apps.first(where: { !$0.isTerminated }) {
        processDebugLog(
            "ProcessUtils: Selected non-terminated app '\(activeApp.localizedName ?? "nil")'",
            "PID: \(activeApp.processIdentifier)",
            "BundleID: \(bundleID)")
        return activeApp.processIdentifier
    }

    processWarningLog(
        "ProcessUtils: All apps for bundle '\(bundleID)' (resolved from path '\(path)') are terminated.")
    return nil
}

func findFrontmostApplicationPid() -> pid_t? {
    processDebugLog("ProcessUtils: findFrontmostApplicationPid called.")
    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        processDebugLog(
            "ProcessUtils: Frontmost app for findFrontmostApplicationPid is '\(frontmostApp.localizedName ?? "nil")'",
            "PID: \(frontmostApp.processIdentifier)",
            "BundleID: \(frontmostApp.bundleIdentifier ?? "nil")",
            "Terminated: \(frontmostApp.isTerminated)"
        )
        return frontmostApp.processIdentifier
    } else {
        processWarningLog(
            "ProcessUtils: NSWorkspace.shared.frontmostApplication returned nil in findFrontmostApplicationPid."
        )
        return nil
    }
}

public func getParentProcessName() -> String? {
    let parentPid = getppid()
    processDebugLog("ProcessUtils: Parent PID is \(parentPid).")
    if let parentApp = NSRunningApplication(processIdentifier: parentPid) {
        processDebugLog(
            "ProcessUtils: Parent app is '\(parentApp.localizedName ?? "nil")'",
            "BundleID: '\(parentApp.bundleIdentifier ?? "nil")'"
        )
        return parentApp.localizedName ?? parentApp.bundleIdentifier
    }
    processWarningLog("ProcessUtils: Could not get NSRunningApplication for parent PID \(parentPid).")
    return nil
}
