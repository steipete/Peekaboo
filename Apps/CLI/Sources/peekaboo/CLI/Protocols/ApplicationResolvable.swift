import AppKit
import Foundation
import PeekabooCore

/// Protocol for commands that can resolve application identifiers from various inputs
protocol ApplicationResolvable {
    /// Application name, bundle ID, or 'PID:12345' format
    var app: String? { get }

    /// Process ID as a direct parameter
    var pid: Int32? { get }
}

extension ApplicationResolvable {
    /// Resolves the application identifier from app and/or pid parameters
    /// Supports lenient handling for redundant but non-conflicting parameters
    func resolveApplicationIdentifier() throws -> String {
        switch (app, pid) {
        case (nil, nil):
            throw PeekabooError.invalidInput("Either --app or --pid must be specified")

        case (let appValue?, nil):
            // Only --app provided, use as-is (supports "PID:12345" format)
            return appValue

        case (nil, let pidValue?):
            // Only --pid provided, convert to PID: format
            return "PID:\(pidValue)"

        case let (appValue?, pidValue?):
            // Both provided - need to validate they don't conflict
            return try self.validateAndResolveBothParameters(app: appValue, pid: pidValue)
        }
    }

    /// Validates when both app and pid parameters are provided
    private func validateAndResolveBothParameters(app: String, pid: Int32) throws -> String {
        // Case 1: Check if app is already in PID format
        if app.hasPrefix("PID:") {
            let appPidString = String(app.dropFirst(4))
            if let appPid = Int32(appPidString) {
                // Both specify PID - they must match
                if appPid == pid {
                    // Redundant but consistent - this is OK
                    Logger.shared.debug("Redundant PID specification: --app '\(app)' --pid \(pid)")
                    return app
                } else {
                    throw PeekabooError.invalidInput(
                        "Conflicting PIDs: --app specifies PID \(appPid) but --pid is \(pid)"
                    )
                }
            } else {
                throw PeekabooError.invalidInput("Invalid PID format in --app: '\(app)'")
            }
        }

        // Case 2: app is a name/bundle ID, pid is provided
        // We need to verify they refer to the same application
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else {
            throw PeekabooError.appNotFound("No application found with PID \(pid)")
        }

        // Check if the app parameter matches this running application
        let appLower = app.lowercased()
        let matchesByName = runningApp.localizedName?.lowercased() == appLower ||
            runningApp.localizedName?.lowercased().contains(appLower) ?? false
        let matchesByBundle = runningApp.bundleIdentifier?.lowercased() == appLower ||
            runningApp.bundleIdentifier?.lowercased().contains(appLower) ?? false

        if matchesByName || matchesByBundle {
            // They match - prefer using the name/bundle ID for better readability
            Logger.shared
                .debug("Validated: --app '\(app)' matches PID \(pid) (\(runningApp.localizedName ?? "Unknown"))")
            return app
        } else {
            // They don't match - this is an error
            let actualName = runningApp.localizedName ?? runningApp.bundleIdentifier ?? "Unknown"
            throw PeekabooError.invalidInput(
                "Application mismatch: --app '\(app)' does not match the application with PID \(pid) (which is '\(actualName)')"
            )
        }
    }
}

/// Extension for commands with positional app argument (like AppCommand subcommands)
protocol ApplicationResolvablePositional: ApplicationResolvable {
    /// Positional application argument
    var app: String { get }
    var pid: Int32? { get }
}

extension ApplicationResolvablePositional {
    // Override to handle non-optional app
    var app: String? { app }
}
