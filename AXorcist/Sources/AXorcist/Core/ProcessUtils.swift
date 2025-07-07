// ProcessUtils.swift - Utilities for process and application inspection.

import AppKit // For NSRunningApplication, NSWorkspace
import Foundation

// debug() is assumed to be globally available from Logging.swift

@MainActor
public func pid(forAppIdentifier ident: String, isDebugLoggingEnabled: Bool,
                currentDebugLogs: inout [String]) -> pid_t? {
    func dLog(_ message: String) {
        if isDebugLoggingEnabled {
            currentDebugLogs.append(message)
        }
    }
    dLog("ProcessUtils: Attempting to find PID for identifier: '\(ident)'")

    if ident == "focused" {
        dLog("ProcessUtils: Identifier is 'focused'. Checking frontmost application.")
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            dLog(
                "ProcessUtils: Frontmost app is '\(frontmostApp.localizedName ?? "nil")' (PID: \(frontmostApp.processIdentifier), BundleID: \(frontmostApp.bundleIdentifier ?? "nil"), Terminated: \(frontmostApp.isTerminated))"
            )
            return frontmostApp.processIdentifier
        } else {
            dLog("ProcessUtils: NSWorkspace.shared.frontmostApplication returned nil.")
            return nil
        }
    }

    dLog("ProcessUtils: Trying by bundle identifier '\(ident)'.")
    let appsByBundleID = NSRunningApplication.runningApplications(withBundleIdentifier: ident)
    if !appsByBundleID.isEmpty {
        dLog("ProcessUtils: Found \(appsByBundleID.count) app(s) by bundle ID '\(ident)'.")
        for (index, app) in appsByBundleID.enumerated() {
            dLog(
                "ProcessUtils: App [\(index)] - Name: '\(app.localizedName ?? "nil")', PID: \(app.processIdentifier), BundleID: '\(app.bundleIdentifier ?? "nil")', Terminated: \(app.isTerminated)"
            )
        }
        if let app = appsByBundleID.first(where: { !$0.isTerminated }) {
            dLog(
                "ProcessUtils: Using first non-terminated app found by bundle ID: '\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier))"
            )
            return app.processIdentifier
        } else {
            dLog(
                "ProcessUtils: All apps found by bundle ID '\(ident)' are terminated or list was empty initially but then non-empty (should not happen)."
            )
        }
    } else {
        dLog("ProcessUtils: No applications found for bundle identifier '\(ident)'.")
    }

    dLog("ProcessUtils: Trying by localized name (case-insensitive) '\(ident)'.")
    let allApps = NSWorkspace.shared.runningApplications
    if let appByName = allApps
        .first(where: { !$0.isTerminated && $0.localizedName?.lowercased() == ident.lowercased() }) {
        dLog(
            "ProcessUtils: Found non-terminated app by localized name: '\(appByName.localizedName ?? "nil")' (PID: \(appByName.processIdentifier), BundleID: '\(appByName.bundleIdentifier ?? "nil")')"
        )
        return appByName.processIdentifier
    } else {
        dLog(
            "ProcessUtils: No non-terminated app found matching localized name '\(ident)'. Found \(allApps.filter { $0.localizedName?.lowercased() == ident.lowercased() }.count) terminated or non-matching apps by this name."
        )
    }

    dLog("ProcessUtils: Trying by path '\(ident)'.")
    let potentialPath = (ident as NSString).expandingTildeInPath
    if FileManager.default.fileExists(atPath: potentialPath),
       let bundle = Bundle(path: potentialPath),
       let bundleId = bundle.bundleIdentifier {
        dLog(
            "ProcessUtils: Path '\(potentialPath)' resolved to bundle '\(bundleId)'. Looking up running apps with this bundle ID."
        )
        let appsByResolvedBundleID = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if !appsByResolvedBundleID.isEmpty {
            dLog("ProcessUtils: Found \(appsByResolvedBundleID.count) app(s) by resolved bundle ID '\(bundleId)'.")
            for (index, app) in appsByResolvedBundleID.enumerated() {
                dLog(
                    "ProcessUtils: App [\(index)] from path - Name: '\(app.localizedName ?? "nil")', PID: \(app.processIdentifier), BundleID: '\(app.bundleIdentifier ?? "nil")', Terminated: \(app.isTerminated)"
                )
            }
            if let app = appsByResolvedBundleID.first(where: { !$0.isTerminated }) {
                dLog(
                    "ProcessUtils: Using first non-terminated app found by path (via bundle ID '\(bundleId)'): '\(app.localizedName ?? "nil")' (PID: \(app.processIdentifier))"
                )
                return app.processIdentifier
            } else {
                dLog("ProcessUtils: All apps for bundle ID '\(bundleId)' (from path) are terminated.")
            }
        } else {
            dLog(
                "ProcessUtils: No running applications found for bundle identifier '\(bundleId)' derived from path '\(potentialPath)'."
            )
        }
    } else {
        dLog("ProcessUtils: Identifier '\(ident)' is not a valid file path or bundle info could not be read.")
    }

    dLog("ProcessUtils: Trying by interpreting '\(ident)' as a PID string.")
    if let pidInt = Int32(ident) {
        if let appByPid = NSRunningApplication(processIdentifier: pidInt), !appByPid.isTerminated {
            dLog(
                "ProcessUtils: Found non-terminated app by PID string '\(ident)': '\(appByPid.localizedName ?? "nil")' (PID: \(appByPid.processIdentifier), BundleID: '\(appByPid.bundleIdentifier ?? "nil")')"
            )
            return pidInt
        } else {
            if NSRunningApplication(processIdentifier: pidInt)?.isTerminated == true {
                dLog("ProcessUtils: String '\(ident)' is a PID, but the app is terminated.")
            } else {
                dLog("ProcessUtils: String '\(ident)' looked like a PID but no running application found for it.")
            }
        }
    }

    dLog("ProcessUtils: PID not found for identifier: '\(ident)'")
    return nil
}

@MainActor
func findFrontmostApplicationPid(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> pid_t? {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    dLog("ProcessUtils: findFrontmostApplicationPid called.")
    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        dLog(
            "ProcessUtils: Frontmost app for findFrontmostApplicationPid is '\(frontmostApp.localizedName ?? "nil")' (PID: \(frontmostApp.processIdentifier), BundleID: '\(frontmostApp.bundleIdentifier ?? "nil")', Terminated: \(frontmostApp.isTerminated))"
        )
        return frontmostApp.processIdentifier
    } else {
        dLog("ProcessUtils: NSWorkspace.shared.frontmostApplication returned nil in findFrontmostApplicationPid.")
        return nil
    }
}

public func getParentProcessName(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    let parentPid = getppid()
    dLog("ProcessUtils: Parent PID is \(parentPid).")
    if let parentApp = NSRunningApplication(processIdentifier: parentPid) {
        dLog(
            "ProcessUtils: Parent app is '\(parentApp.localizedName ?? "nil")' (BundleID: '\(parentApp.bundleIdentifier ?? "nil")')"
        )
        return parentApp.localizedName ?? parentApp.bundleIdentifier
    }
    dLog("ProcessUtils: Could not get NSRunningApplication for parent PID \(parentPid).")
    return nil
}
