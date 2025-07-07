//
//  RunningApplicationHelper.swift
//  AXorcist
//
//  Helper utilities for discovering and working with running applications
//

import ApplicationServices
import Foundation
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(CoreGraphics)
    import CoreGraphics // Added for CGWindowListCopyWindowInfo
#endif

public struct RunningApplicationHelper {
    /// Options for filtering running applications
    public struct FilterOptions {
        // MARK: Lifecycle

        public init(
            excludeProhibitedApps: Bool = true,
            requireBundleIdentifier: Bool = true,
            excludeSystemProcesses: Bool = true,
            sortAlphabetically: Bool = true,
            activeOnly: Bool = false
        ) {
            self.excludeProhibitedApps = excludeProhibitedApps
            self.requireBundleIdentifier = requireBundleIdentifier
            self.excludeSystemProcesses = excludeSystemProcesses
            self.sortAlphabetically = sortAlphabetically
            self.activeOnly = activeOnly
        }

        // MARK: Public

        /// Include only applications with regular or accessory activation policy
        public var excludeProhibitedApps: Bool = true
        /// Exclude applications with no bundle identifier
        public var requireBundleIdentifier: Bool = true
        /// Exclude system processes (PID <= 0)
        public var excludeSystemProcesses: Bool = true
        /// Sort applications alphabetically by name
        public var sortAlphabetically: Bool = true
        /// Include only applications that are currently active
        public var activeOnly: Bool = false
    }

    /// Get the current application
    public static var currentApplication: NSRunningApplication {
        #if canImport(AppKit)
            return NSRunningApplication.current
        #else
            // Fallback - create a minimal implementation
            fatalError("NSRunningApplication.current not available on this platform")
        #endif
    }

    /// Get the current application's process info
    public static var currentProcessInfo: ProcessInfo {
        ProcessInfo.processInfo
    }

    /// Get the current application's PID
    public static var currentPID: pid_t {
        ProcessInfo.processInfo.processIdentifier
    }

    /// Get the frontmost application
    public static var frontmostApplication: NSRunningApplication? {
        #if canImport(AppKit)
            return NSWorkspace.shared.frontmostApplication
        #else
            return nil
        #endif
    }

    /// Get all currently running applications
    public static func allApplications() -> [NSRunningApplication] {
        #if canImport(AppKit)
            return NSWorkspace.shared.runningApplications
        #else
            // On non-AppKit platforms, we need to use different approach
            // For now, return empty array - could be enhanced with CGWindowListCopyWindowInfo
            return []
        #endif
    }

    /// Get filtered running applications based on options
    public static func filteredApplications(options: FilterOptions = FilterOptions()) -> [NSRunningApplication] {
        #if canImport(AppKit)
            var apps = allApplications()

            // Apply filters
            if options.excludeProhibitedApps {
                apps = apps.filter { $0.activationPolicy != .prohibited }
            }

            if options.requireBundleIdentifier {
                apps = apps.filter { $0.bundleIdentifier != nil }
            }

            if options.excludeSystemProcesses {
                apps = apps.filter { $0.processIdentifier > 0 }
            }

            if options.activeOnly {
                apps = apps.filter(\.isActive)
            }

            // Sort if requested
            if options.sortAlphabetically {
                apps.sort { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            }

            return apps
        #else
            return []
        #endif
    }

    /// Get applications suitable for accessibility inspection (convenience method)
    public static func accessibleApplications() -> [NSRunningApplication] {
        filteredApplications(options: FilterOptions(
            excludeProhibitedApps: true,
            requireBundleIdentifier: true,
            excludeSystemProcesses: true,
            sortAlphabetically: true
        ))
    }

    /// Get running applications that have on-screen windows and are accessible.
    @MainActor 
    public static func accessibleApplicationsWithOnScreenWindows() -> [NSRunningApplication] {
        #if canImport(AppKit) && canImport(CoreGraphics)
            // 1. Get ALL visible windows in one native call
            guard let list = CGWindowListCopyWindowInfo(
                [CFConstants.cgWindowListOptionOnScreenOnly, CFConstants.cgWindowListExcludeDesktopElements],
                CFConstants.cgNullWindowID
            ) as? [[String: Any]] else {
                // Consider logging an error here if a logging mechanism is available
                // For now, returning empty or falling back to just accessible apps
                axErrorLog("RunningApplicationHelper: Failed to get CGWindowListCopyWindowInfo")
                return [] // Or potentially: return accessibleApplications()
            }

            // 2. Collect PIDs that own at least one window
            let pidsWithWindows = Set(list.compactMap { $0[CFConstants.cgWindowOwnerPID] as? pid_t })

            // 3. Get all running applications that are also accessible
            let accessibleApps = self.accessibleApplications()

            // 4. Filter accessible applications to include only those with on-screen windows
            return accessibleApps.filter { pidsWithWindows.contains($0.processIdentifier) }
        #else
            // Fallback for platforms without AppKit or CoreGraphics (e.g., Linux if ever supported)
            // Or if one of them is missing, which is unlikely for macOS targets
            axWarningLog(
                "RunningApplicationHelper: AppKit or CoreGraphics not available, cannot filter for on-screen windows."
            )
            return accessibleApplications() // Return all accessible apps as a fallback
        #endif
    }

    /// Get a running application by its process ID
    public static func runningApplication(pid: pid_t) -> NSRunningApplication? {
        #if canImport(AppKit)
            return allApplications().first { $0.processIdentifier == pid }
        #else
            return nil
        #endif
    }

    /// Find applications by bundle identifier
    public static func applications(withBundleIdentifier bundleID: String) -> [NSRunningApplication] {
        #if canImport(AppKit)
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        #else
            return []
        #endif
    }

    /// Check if an application is running by bundle ID
    public static func isApplicationRunning(bundleID: String) -> Bool {
        !applications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Get application info from PID using AX API
    @MainActor
    public static func applicationInfo(for pid: pid_t) -> (name: String?, bundleID: String?)? {
        let app = AXUIElement.application(pid: pid)
        let element = Element(app)

        // Try to get the application name from the title
        let name = element.title()

        // For bundle ID, we need to use NSRunningApplication if available
        #if canImport(AppKit)
            let bundleID = runningApplication(pid: pid)?.bundleIdentifier
        #else
            let bundleID: String? = nil
        #endif

        return (name, bundleID)
    }

    // MARK: - Notification Helpers

    #if canImport(AppKit)
        /// Subscribe to application launch notifications
        public static func observeApplicationLaunches(handler: @escaping @Sendable (NSRunningApplication) -> Void)
            -> NSObjectProtocol
        {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    handler(app)
                }
            }
        }

        /// Subscribe to application termination notifications
        public static func observeApplicationTerminations(handler: @escaping @Sendable (NSRunningApplication) -> Void)
            -> NSObjectProtocol
        {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    handler(app)
                }
            }
        }

        /// Subscribe to application activation notifications
        public static func observeApplicationActivations(handler: @escaping @Sendable (NSRunningApplication) -> Void)
            -> NSObjectProtocol
        {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    handler(app)
                }
            }
        }
    #endif

    // MARK: - Convenience Methods

    /// Get display name for an application (localized name or bundle ID or PID)
    public static func displayName(for app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? "App PID \(app.processIdentifier)"
    }

    /// Check if an application is likely accessible for UI inspection
    public static func isAccessible(_ app: NSRunningApplication) -> Bool {
        #if canImport(AppKit)
            return app.activationPolicy != .prohibited &&
                app.processIdentifier > 0 &&
                app.bundleIdentifier != nil
        #else
            return app.processIdentifier > 0
        #endif
    }
}
