import AppKit
import AXorcist
import Foundation
import os.log
import PeekabooFoundation

/**
 * Application discovery and management service for macOS automation.
 *
 * Provides intelligent application lookup, window enumeration, and process management.
 * Supports multiple identification formats including PID, bundle ID, application name,
 * and fuzzy matching with defensive programming for app lifecycle complexities.
 *
 * ## Core Capabilities
 * - Application discovery with multiple identifier formats
 * - Window enumeration and counting via accessibility APIs
 * - Process management and focus control
 * - Fuzzy name matching with GUI app preference
 *
 * ## Identification Formats
 * - `"PID:1234"` - Direct process ID lookup
 * - `"com.apple.Safari"` - Bundle identifier matching
 * - `"Safari"` - Name matching (case-insensitive)
 * - `"Saf"` - Fuzzy matching for partial names
 *
 * ## Usage Example
 * ```swift
 * let appService = ApplicationService()
 *
 * // List all applications
 * let result = try await appService.listApplications()
 * for app in result.data.applications {
 *     print("\(app.name): \(app.windowCount) windows")
 * }
 *
 * // Find specific application
 * let safari = try await appService.findApplication(identifier: "Safari")
 * ```
 *
 * - Important: Requires Accessibility permission for window enumeration
 * - Note: Performance 5-200ms depending on operation and system load
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class ApplicationService: ApplicationServiceProtocol {
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "ApplicationService")
    private let windowIdentityService = WindowIdentityService()

    // Timeout for accessibility API calls to prevent hangs
    private static let axTimeout: Float = 2.0 // 2 seconds instead of default 6 seconds

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init() {
        // Set global AX timeout to prevent hangs
        AXTimeoutConfiguration.setGlobalTimeout(Self.axTimeout)

        // Connect to visualizer if available
        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}

@MainActor
extension ApplicationService {
    public func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        let startTime = Date()
        self.logger.info("Listing all running applications")

        // Already on main thread due to @MainActor on class
        let runningApps = NSWorkspace.shared.runningApplications

        self.logger.debug("Found \(runningApps.count) running processes")

        // Filter apps first with defensive checks
        let appsToProcess = runningApps.compactMap { app -> NSRunningApplication? in
            // Defensive check - ensure app is valid
            guard !app.isTerminated else { return nil }

            // Skip apps without a localized name
            guard app.localizedName != nil else { return nil }

            // Skip system/background apps
            if app.activationPolicy == .prohibited {
                return nil
            }

            return app
        }

        // Now create app info with window counts
        let filteredApps = appsToProcess.compactMap { app -> ServiceApplicationInfo? in
            // Defensive check in case app terminated while processing
            guard !app.isTerminated else { return nil }
            return self.createApplicationInfo(from: app)
        }.sorted { app1, app2 -> Bool in
            return app1.name < app2.name
        }

        self.logger.info("Returning \(filteredApps.count) visible applications")

        // Find active app and calculate counts
        let activeApp = filteredApps.first { $0.isActive }
        let appsWithWindows = filteredApps.filter { $0.windowCount > 0 }
        let totalWindows = filteredApps.reduce(0) { $0 + $1.windowCount }

        // Build highlights
        var highlights: [UnifiedToolOutput<ServiceApplicationListData>.Summary.Highlight] = []
        if let active = activeApp {
            highlights.append(.init(
                label: active.name,
                value: "\(active.windowCount) window\(active.windowCount == 1 ? "" : "s")",
                kind: .primary))
        }

        return UnifiedToolOutput(
            data: ServiceApplicationListData(applications: filteredApps),
            summary: UnifiedToolOutput.Summary(
                brief: "Found \(filteredApps.count) running application\(filteredApps.count == 1 ? "" : "s")",
                detail: nil,
                status: .success,
                counts: [
                    "applications": filteredApps.count,
                    "appsWithWindows": appsWithWindows.count,
                    "totalWindows": totalWindows,
                ],
                highlights: highlights),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                warnings: [],
                hints: ["Use app name or PID to target specific application"]))
    }

    /**
     * Find a specific application using flexible identification formats.
     *
     * - Parameter identifier: Application identifier in one of these formats:
     *   - Process ID: `"PID:1234"` for direct process lookup
     *   - Bundle ID: `"com.apple.Safari"` for exact bundle identifier matching
     *   - App Name: `"Safari"` for case-insensitive name matching
     *   - Partial Name: `"Saf"` for fuzzy matching when exact match fails
     * - Returns: `ServiceApplicationInfo` containing application details and window count
     * - Throws: `PeekabooError.appNotFound` if no matching application is found
     *
     * ## Matching Priority
     * 1. Exact PID match (if identifier starts with "PID:")
     * 2. Exact bundle ID match
     * 3. Exact name match (case-insensitive)
     * 4. Fuzzy partial name match
     * 5. GUI applications preferred over background processes
     *
     * ## Examples
     * ```swift
     * // Find by exact name
     * let safari = try await appService.findApplication(identifier: "Safari")
     *
     * // Find by process ID
     * let app = try await appService.findApplication(identifier: "PID:1234")
     *
     * // Find by bundle ID
     * let chrome = try await appService.findApplication(identifier: "com.google.Chrome")
     *
     * // Fuzzy match
     * let xcode = try await appService.findApplication(identifier: "Xcod") // Matches "Xcode"
     * ```
     */
    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        self.logger.info("Finding application with identifier: \(identifier, privacy: .public)")

        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated
        }

        if let pid = Self.parsePID(identifier),
           let app = runningApps.first(where: { $0.processIdentifier == pid })
        {
            return self.createApplicationInfo(from: app)
        }

        if let bundleMatch = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            return self.createApplicationInfo(from: bundleMatch)
        }

        if let exactName = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.compare(identifier, options: .caseInsensitive) == .orderedSame
        }) {
            return self.createApplicationInfo(from: exactName)
        }

        if let fuzzy = runningApps.first(where: { app in
            guard app.activationPolicy != .prohibited,
                  let name = app.localizedName
            else { return false }
            return name.localizedCaseInsensitiveContains(identifier)
        }) {
            return self.createApplicationInfo(from: fuzzy)
        }

        self.logger.error("Application not found: \(identifier, privacy: .public)")
        throw PeekabooError.appNotFound(identifier)
    }

    private static func parsePID(_ identifier: String) -> Int32? {
        guard identifier.uppercased().hasPrefix("PID:") else { return nil }
        return Int32(identifier.dropFirst(4))
    }

    public func listWindows(
        for appIdentifier: String,
        timeout: Float? = nil) async throws -> UnifiedToolOutput<ServiceWindowListData>
    {
        let startTime = Date()
        self.logger.info("Listing windows for application: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)
        let hasScreenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()

        let context = WindowEnumerationContext(
            service: self,
            app: app,
            startTime: startTime,
            axTimeout: timeout ?? Self.axTimeout,
            hasScreenRecording: hasScreenRecording,
            logger: self.logger)
        return await context.run()
    }

    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        self.logger.info("Getting frontmost application")

        // Already on main thread due to @MainActor on class
        guard let app = NSWorkspace.shared.frontmostApplication else {
            self.logger.error("No frontmost application found")
            throw PeekabooError.appNotFound("frontmost")
        }

        self.logger.debug("Frontmost app: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        return self.createApplicationInfo(from: app)
    }

    public func isApplicationRunning(identifier: String) async -> Bool {
        self.logger.debug("Checking if application is running: \(identifier)")
        do {
            _ = try await self.findApplication(identifier: identifier)
            self.logger.debug("Application is running: \(identifier)")
            return true
        } catch {
            self.logger.debug("Application is not running: \(identifier)")
            return false
        }
    }

    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        self.logger.info("Launching application: \(identifier)")

        // First check if already running
        do {
            let existingApp = try await findApplication(identifier: identifier)
            self.logger.debug("Application already running: \(existingApp.name)")
            return existingApp
        } catch {
            self.logger.debug("Application not currently running: \(identifier), will try to launch")
        }

        // Try to launch by bundle ID
        // Find the app URL
        let appURL: URL
        // Already on main thread due to @MainActor on class
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            self.logger.debug("Found app by bundle ID at: \(url.path)")
            appURL = url
        } else if let url = findApplicationByName(identifier) {
            self.logger.debug("Found app by name at: \(url.path)")
            appURL = url
        } else {
            self.logger.error("Application not found in system: \(identifier)")
            throw PeekabooError.appNotFound(identifier)
        }

        // Launch the application
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        self.logger.debug("Launching app from URL: \(appURL.path)")

        // Extract app name and icon path
        let appName = appURL.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let iconPath = appURL.appendingPathComponent("Contents/Resources/AppIcon.icns").path
        let hasIcon = FileManager.default.fileExists(atPath: iconPath)

        // Show app launch animation
        _ = await self.visualizerClient.showAppLaunch(appName: appName, iconPath: hasIcon ? iconPath : nil)

        // Already on main thread due to @MainActor on class
        let runningApp = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)

        // Wait a bit for the app to fully launch
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let launchMessage =
            "Successfully launched: \(runningApp.localizedName ?? "Unknown") (PID: \(runningApp.processIdentifier))"
        self.logger.info("\(launchMessage)")
        return self.createApplicationInfo(from: runningApp)
    }

    public func activateApplication(identifier: String) async throws {
        self.logger.info("Activating application: \(identifier)")
        let app = try await findApplication(identifier: identifier)

        // Create NSRunningApplication
        let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier)
        guard let runningApp else {
            throw PeekabooError.operationError(
                message: "Failed to activate application: Could not find running application process")
        }

        let activated = runningApp.activate(options: [])

        if !activated {
            self.logger.error("Failed to activate application: \(app.name). Continuing without activation.")
            return
        }

        self.logger.info("Successfully activated: \(app.name)")
        // Wait for activation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    public func quitApplication(identifier: String, force: Bool = false) async throws -> Bool {
        self.logger.info("Quitting application: \(identifier) (force: \(force))")
        let app = try await findApplication(identifier: identifier)

        // Create NSRunningApplication
        let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier)
        guard let runningApp else {
            throw PeekabooError.appNotFound(identifier)
        }

        // Try to get app icon path for animation
        var iconPath: String?
        if let bundleURL = runningApp.bundleURL {
            let potentialIconPath = bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns").path
            if FileManager.default.fileExists(atPath: potentialIconPath) {
                iconPath = potentialIconPath
            }
        }

        // Show app quit animation
        _ = await self.visualizerClient.showAppQuit(appName: app.name, iconPath: iconPath)

        self.logger.debug("Sending \(force ? "force terminate" : "terminate") signal to \(app.name)")
        let success = force ? runningApp.forceTerminate() : runningApp.terminate()

        // Wait a bit for the termination to complete
        if success {
            self.logger.info("Successfully quit: \(app.name)")
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        } else {
            self.logger.error("Failed to quit: \(app.name)")
        }

        return success
    }

    public func hideApplication(identifier: String) async throws {
        self.logger.info("Hiding application: \(identifier)")
        let app = try await findApplication(identifier: identifier)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        do {
            try appElement.performAction(Attribute<String>("AXHide"))
            self.logger.debug("Hidden via AX action: \(app.name)")
        } catch {
            // Log the error but use fallback
            _ = error.asPeekabooError(context: "AX hide action failed for \(app.name)")
            // Fallback to NSRunningApplication method
            self.logger.debug("Using NSRunningApplication fallback")
            // Create NSRunningApplication and hide it
            let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier)
            if let runningApp {
                runningApp.hide()
                self.logger.debug("Hidden via NSRunningApplication: \(app.name)")
            }
        }
    }

    public func unhideApplication(identifier: String) async throws {
        self.logger.info("Unhiding application: \(identifier)")
        let app = try await findApplication(identifier: identifier)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        do {
            try appElement.performAction(Attribute<String>("AXUnhide"))
            self.logger.debug("Unhidden via AX action: \(app.name)")
        } catch {
            // Log the error but use fallback
            _ = error.asPeekabooError(context: "AX unhide action failed for \(app.name)")
            // Fallback to activating the app if unhide fails
            self.logger.debug("Using activate fallback")
            // Create NSRunningApplication and activate it
            let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier)
            if let runningApp {
                runningApp.activate()
                self.logger.debug("Activated as fallback: \(app.name)")
            }
        }
    }

    public func hideOtherApplications(identifier: String) async throws {
        self.logger.info("Hiding other applications except: \(identifier)")
        let app = try await findApplication(identifier: identifier)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        do {
            // Use custom attribute for hide others action
            try appElement.performAction(Attribute<String>("AXHideOthers"))
            self.logger.debug("Hidden others via AX action")
        } catch {
            // Log the error but use fallback
            _ = error.asPeekabooError(context: "AX hide others action failed")
            // Fallback: hide each app individually
            self.logger.debug("Hiding apps individually")
            // Already on main thread due to @MainActor on class
            let apps = NSWorkspace.shared.runningApplications
            var hiddenCount = 0
            for runningApp in apps {
                if runningApp.processIdentifier != app.processIdentifier,
                   runningApp.activationPolicy == .regular,
                   runningApp.bundleIdentifier != "com.apple.finder"
                {
                    runningApp.hide()
                    hiddenCount += 1
                }
            }
            // Return value already computed
            self.logger.debug("Hidden \(hiddenCount) other applications")
        }
    }

    public func showAllApplications() async throws {
        self.logger.info("Showing all applications")
        let systemWide = Element.systemWide()

        do {
            // Use custom attribute for show all action
            try systemWide.performAction(Attribute<String>("AXShowAll"))
            self.logger.debug("Shown all via AX action")
        } catch {
            // Log the error but use fallback
            _ = error.asPeekabooError(context: "AX show all action failed")
            // Fallback: unhide each hidden app
            self.logger.debug("Unhiding apps individually")
            // Already on main thread due to @MainActor on class
            let apps = NSWorkspace.shared.runningApplications
            var unhiddenCount = 0
            for runningApp in apps {
                if runningApp.isHidden, runningApp.activationPolicy == .regular {
                    runningApp.unhide()
                    unhiddenCount += 1
                }
            }
            // Return value already computed
            self.logger.debug("Unhidden \(unhiddenCount) applications")
        }
    }
}

// MARK: - Private Helpers

@MainActor
extension ApplicationService {
    private func createApplicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: self.getWindowCount(for: app))
    }

    fileprivate func createWindowInfo(from window: Element, index: Int) async -> ServiceWindowInfo? {
        guard let title = window.title() else { return nil }

        let bounds = self.windowBounds(for: window)
        let screen = self.screenInfo(for: bounds)
        let windowID = self.resolveWindowID(for: window, title: title, bounds: bounds, fallbackIndex: index)
        let spaces = self.spaceInfo(for: windowID)
        let level = self.windowLevel(for: windowID)

        return ServiceWindowInfo(
            windowID: Int(windowID),
            title: title,
            bounds: bounds,
            isMinimized: window.isMinimized() ?? false,
            isMainWindow: window.isMain() ?? false,
            windowLevel: level,
            index: index,
            spaceID: spaces.spaceID,
            spaceName: spaces.spaceName,
            screenIndex: screen.index,
            screenName: screen.name)
    }

    private func windowBounds(for window: Element) -> CGRect {
        let position = window.position() ?? .zero
        let size = window.size() ?? .zero
        return CGRect(origin: position, size: size)
    }

    fileprivate func screenInfo(for bounds: CGRect) -> (index: Int?, name: String?) {
        let screenService = ScreenService()
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)
        return (screenInfo?.index, screenInfo?.name)
    }

    private func resolveWindowID(for window: Element, title: String, bounds: CGRect, fallbackIndex: Int) -> CGWindowID {
        let windowIdentityService = WindowIdentityService()
        if let identifier = windowIdentityService.getWindowID(from: window) {
            return identifier
        }

        if let pid = window.pid(), let matched = matchWindowID(pid: pid, title: title, bounds: bounds) {
            return matched
        }

        let missingIdentifierMessage =
            "Failed to get actual window ID for window '\(title)', using index \(fallbackIndex) as fallback"
        self.logger.warning("\(missingIdentifierMessage)")
        return CGWindowID(fallbackIndex)
    }

    private func matchWindowID(pid: pid_t, title: String, bounds: CGRect) -> CGWindowID? {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let windowTitle = windowInfo[kCGWindowName as String] as? String,
                  windowTitle == title,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat
            else {
                continue
            }

            let cgBounds = CGRect(x: x, y: y, width: width, height: height)

            let withinTolerance = abs(cgBounds.origin.x - bounds.origin.x) < 5 &&
                abs(cgBounds.origin.y - bounds.origin.y) < 5 &&
                abs(cgBounds.size.width - bounds.size.width) < 5 &&
                abs(cgBounds.size.height - bounds.size.height) < 5

            if withinTolerance, let windowNumber = windowInfo[kCGWindowNumber as String] as? Int {
                self.logger.debug("Found window ID \(windowNumber) via CGWindowList for '\(title)'")
                return CGWindowID(windowNumber)
            }
        }

        return nil
    }

    private func spaceInfo(for windowID: CGWindowID) -> (spaceID: UInt64?, spaceName: String?) {
        let spaceService = SpaceManagementService()
        let spaces = spaceService.getSpacesForWindow(windowID: windowID)
        guard let firstSpace = spaces.first else {
            return (nil, nil)
        }
        return (firstSpace.id, firstSpace.name)
    }

    fileprivate func windowLevel(for windowID: CGWindowID) -> Int {
        let spaceService = SpaceManagementService()
        return spaceService.getWindowLevel(windowID: windowID).map { Int($0) } ?? 0
    }

    @MainActor
    private func getWindowCount(for app: NSRunningApplication) -> Int {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        if let windows = appElement.windows(), !windows.isEmpty {
            let renderable = windows.filter { window -> Bool in
                guard let frame = window.frame() else { return false }
                return frame.width >= 50 && frame.height >= 50
            }

            if !renderable.isEmpty {
                return renderable.count
            }

            return windows.count
        }

        let cgWindows = self.windowIdentityService.getWindows(for: app)
        if cgWindows.isEmpty { return 0 }

        let renderable = cgWindows.filter(\.isRenderable)
        return renderable.isEmpty ? cgWindows.count : renderable.count
    }

    public func getApplicationWithWindowCount(identifier: String) async throws -> ServiceApplicationInfo {
        self.logger.info("Getting application with window count: \(identifier)")
        var appInfo = try await findApplication(identifier: identifier)

        // Now query window count only for this specific app
        let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier)
        let windowCount = runningApp.map { self.getWindowCount(for: $0) } ?? 0

        appInfo.windowCount = windowCount
        return appInfo
    }

    @MainActor
    private func findApplicationByName(_ name: String) -> URL? {
        self.logger.debug("Searching for application by name: \(name)")

        // First, try exact name in common directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "~/Applications",
        ].map { NSString(string: $0).expandingTildeInPath }

        let fileManager = FileManager.default

        for path in searchPaths {
            let searchName = name.hasSuffix(".app") ? name : "\(name).app"
            let fullPath = (path as NSString).appendingPathComponent(searchName)

            if fileManager.fileExists(atPath: fullPath) {
                self.logger.debug("Found app at: \(fullPath)")
                return URL(fileURLWithPath: fullPath)
            }
        }

        // Try NSWorkspace API with bundle ID
        // Already on main thread due to @MainActor on class
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            self.logger.debug("Found app via bundle identifier: \(url.path)")
            return url
        }

        // Use Spotlight search for more flexible app discovery
        if let url = searchApplicationWithSpotlight(name) {
            self.logger.debug("Found app via Spotlight: \(url.path)")
            return url
        }

        self.logger.debug("Application not found by name: \(name)")
        return nil
    }

    @MainActor
    private func searchApplicationWithSpotlight(_ name: String) -> URL? {
        SpotlightApplicationSearcher(logger: self.logger, name: name).search()
    }

    // MARK: - Helper for building window list output

    fileprivate func buildWindowListOutput(
        windows: [ServiceWindowInfo],
        app: ServiceApplicationInfo,
        startTime: Date,
        warnings: [String]) -> UnifiedToolOutput<ServiceWindowListData>
    {
        let processedCount = windows.count

        // Build highlights
        var highlights: [UnifiedToolOutput<ServiceWindowListData>.Summary.Highlight] = []
        let minimizedCount = windows.count(where: { $0.isMinimized })
        let offScreenCount = windows.count(where: { $0.isOffScreen })

        if minimizedCount > 0 {
            highlights.append(.init(
                label: "Minimized",
                value: "\(minimizedCount) window\(minimizedCount == 1 ? "" : "s")",
                kind: .info))
        }

        if offScreenCount > 0 {
            highlights.append(.init(
                label: "Off-screen",
                value: "\(offScreenCount) window\(offScreenCount == 1 ? "" : "s")",
                kind: .warning))
        }

        return UnifiedToolOutput(
            data: ServiceWindowListData(windows: windows, targetApplication: app),
            summary: UnifiedToolOutput.Summary(
                brief: "Found \(processedCount) window\(processedCount == 1 ? "" : "s") for \(app.name)",
                status: .success,
                counts: [
                    "windows": processedCount,
                    "minimized": minimizedCount,
                    "offScreen": offScreenCount,
                ],
                highlights: highlights),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                warnings: warnings,
                hints: ["Use window title or index to target specific window"]))
    }
}

// MARK: - Window enumeration support

@MainActor
private struct WindowEnumerationContext {
    struct CGSnapshot {
        let windows: [ServiceWindowInfo]
        let windowsByTitle: [String: ServiceWindowInfo]
    }

    struct AXWindowResult {
        let windows: [Element]
        let timedOut: Bool
    }

    unowned let service: ApplicationService
    let app: ServiceApplicationInfo
    let startTime: Date
    let axTimeout: Float
    let hasScreenRecording: Bool
    let logger: Logger

    func run() async -> UnifiedToolOutput<ServiceWindowListData> {
        let snapshot = self.hasScreenRecording ? self.collectCGSnapshot() : nil
        if let snapshot, let fast = fastPath(using: snapshot) {
            return fast
        }

        guard self.isApplicationRunning else {
            return self.terminatedOutput()
        }

        let axWindows = self.fetchAXWindows()
        if let snapshot {
            return await self.mergeWithSnapshot(snapshot, axResult: axWindows)
        }

        return await self.buildAXOnlyResult(from: axWindows)
    }

    private var isApplicationRunning: Bool {
        NSRunningApplication(processIdentifier: self.app.processIdentifier)?.isTerminated == false
    }

    private func collectCGSnapshot() -> CGSnapshot? {
        self.logger.debug("Using hybrid approach: CGWindowList + selective AX enrichment")
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var windowIndex = 0
        var windows: [ServiceWindowInfo] = []
        var windowsByTitle: [String: ServiceWindowInfo] = [:]
        let screenService = ScreenService()
        let spaceService = SpaceManagementService()

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier
            else {
                continue
            }

            guard let windowInfo = snapshotWindowInfo(
                from: windowInfo,
                index: windowIndex,
                screenService: screenService,
                spaceService: spaceService)
            else {
                continue
            }

            windows.append(windowInfo)
            if !windowInfo.title.isEmpty {
                windowsByTitle[windowInfo.title] = windowInfo
            } else {
                let missingTitleMessage =
                    "Window \(windowInfo.windowID) has no title in CGWindowList, will need AX enrichment"
                self.logger.debug("\(missingTitleMessage)")
            }
            windowIndex += 1
        }

        guard !windows.isEmpty else {
            return nil
        }

        self.logger.debug("CGWindowList found \(windows.count) windows for \(self.app.name)")
        return CGSnapshot(windows: windows, windowsByTitle: windowsByTitle)
    }

    private func snapshotWindowInfo(
        from windowInfo: [String: Any],
        index: Int,
        screenService: ScreenService,
        spaceService: SpaceManagementService) -> ServiceWindowInfo?
    {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }

        let bounds = CGRect(x: x, y: y, width: width, height: height)
        let windowID = windowInfo[kCGWindowNumber as String] as? Int ?? index
        let windowLevel = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
        let windowTitle = (windowInfo[kCGWindowName as String] as? String) ?? ""
        let isMinimized = bounds.origin.x < -10000 || bounds.origin.y < -10000
        let spaces = spaceService.getSpacesForWindow(windowID: CGWindowID(windowID))
        let (spaceID, spaceName) = spaces.first.map { ($0.id, $0.name) } ?? (nil, nil)
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)

        return ServiceWindowInfo(
            windowID: windowID,
            title: windowTitle,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: index == 0,
            windowLevel: windowLevel,
            alpha: alpha,
            index: index,
            spaceID: spaceID,
            spaceName: spaceName,
            screenIndex: screenInfo?.index,
            screenName: screenInfo?.name)
    }

    private func fastPath(using snapshot: CGSnapshot) -> UnifiedToolOutput<ServiceWindowListData>? {
        guard snapshot.windows.allSatisfy({ !$0.title.isEmpty }) else {
            return nil
        }

        self.logger.debug("All windows have titles from CGWindowList, using fast path")
        return self.service.buildWindowListOutput(
            windows: snapshot.windows,
            app: self.app,
            startTime: self.startTime,
            warnings: [])
    }

    private func terminatedOutput() -> UnifiedToolOutput<ServiceWindowListData> {
        self.logger.warning("Application \(self.app.name) appears to have terminated")
        return UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: self.app),
            summary: UnifiedToolOutput.Summary(
                brief: "Application \(self.app.name) has no windows (app terminated)",
                status: .failed,
                counts: ["windows": 0]),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(self.startTime),
                warnings: ["Application appears to have terminated"]))
    }

    private func fetchAXWindows() -> AXWindowResult {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        appElement.setMessagingTimeout(self.axTimeout)
        defer { appElement.setMessagingTimeout(0) }

        let windowStartTime = Date()
        let windows = appElement.windowsWithTimeout(timeout: self.axTimeout) ?? []
        let timedOut = Date().timeIntervalSince(windowStartTime) >= Double(self.axTimeout)
        return AXWindowResult(windows: windows, timedOut: timedOut)
    }

    private func mergeWithSnapshot(
        _ snapshot: CGSnapshot,
        axResult: AXWindowResult) async -> UnifiedToolOutput<ServiceWindowListData>
    {
        var enrichedWindows: [ServiceWindowInfo] = []
        var warnings: [String] = []

        for (index, axWindow) in axResult.windows.enumerated() {
            if Date().timeIntervalSince(self.startTime) > Double(self.axTimeout * 2) {
                warnings.append("Stopped enrichment after timeout")
                break
            }

            guard let axTitle = axWindow.title(), !axTitle.isEmpty else {
                continue
            }

            if let cgWindow = snapshot.windowsByTitle[axTitle] {
                enrichedWindows.append(cgWindow)
            } else if let windowInfo = await service.createWindowInfo(from: axWindow, index: index) {
                enrichedWindows.append(windowInfo)
            }
        }

        for cgWindow in snapshot.windows where !enrichedWindows.contains(where: { $0.windowID == cgWindow.windowID }) {
            if cgWindow.title.isEmpty {
                logger.debug("CGWindow \(cgWindow.windowID) has no title, including as-is")
            }
            enrichedWindows.append(cgWindow)
        }

        if axResult.timedOut {
            warnings.append("Window enumeration timed out after \(self.axTimeout)s, results may be incomplete")
        }

        return self.service.buildWindowListOutput(
            windows: enrichedWindows,
            app: self.app,
            startTime: self.startTime,
            warnings: warnings)
    }

    private func buildAXOnlyResult(from axResult: AXWindowResult) async -> UnifiedToolOutput<ServiceWindowListData> {
        self.logger.debug("Using pure AX approach (no screen recording permission)")
        var warnings: [String] = []
        var windowInfos: [ServiceWindowInfo] = []
        let maxWindowsToProcess = 100
        let limitedWindows = Array(axResult.windows.prefix(maxWindowsToProcess))

        if axResult.windows.count > maxWindowsToProcess {
            let warning =
                "Application \(app.name) has \(axResult.windows.count) windows, " +
                "processing only first \(maxWindowsToProcess)"
            self.logger.warning("\(warning)")
        }

        for (index, window) in limitedWindows.enumerated() {
            if Date().timeIntervalSince(self.startTime) > Double(self.axTimeout) {
                warnings.append("Stopped processing after \(self.axTimeout)s timeout")
                break
            }

            if let windowInfo = await service.createWindowInfo(from: window, index: index) {
                windowInfos.append(windowInfo)
            }
        }

        if axResult.timedOut {
            warnings.append("Window enumeration timed out, results may be incomplete")
        }

        if axResult.windows.count > maxWindowsToProcess {
            let processedWarning =
                "Only processed first \(maxWindowsToProcess) of \(axResult.windows.count) windows"
            warnings.append(processedWarning)
        }

        if !self.hasScreenRecording {
            warnings.append("Screen recording permission not granted - window listing may be slower")
        }

        return self.service.buildWindowListOutput(
            windows: windowInfos,
            app: self.app,
            startTime: self.startTime,
            warnings: warnings)
    }
}

// MARK: - Spotlight search helper

@MainActor
private struct SpotlightApplicationSearcher {
    let logger: Logger
    let name: String

    func search() -> URL? {
        self.logger.debug("Using Spotlight to search for: \(self.name)")
        let query = self.makeQuery()
        query.start()
        self.waitForResults(query)
        query.stop()
        self.logger.debug("Spotlight query completed with \(query.resultCount) results")

        guard let match = bestMatch(in: query) else {
            return nil
        }

        let resultMessage = "Spotlight found app: \(match.url.path) (score: \(match.score))"
        self.logger.debug("\(resultMessage)")
        return match.url
    }

    private func makeQuery() -> NSMetadataQuery {
        let query = NSMetadataQuery()
        let predicateFormat =
            "(kMDItemContentType == 'com.apple.application-bundle' || kMDItemContentType == 'com.apple.application')" +
            " && (kMDItemDisplayName CONTAINS[cd] %@ || kMDItemFSName CONTAINS[cd] %@)"
        query.predicate = NSPredicate(format: predicateFormat, self.name, self.name)
        query.searchScopes = [
            NSMetadataQueryIndexedLocalComputerScope,
            NSMetadataQueryIndexedNetworkScope,
        ]
        return query
    }

    private func waitForResults(_ query: NSMetadataQuery) {
        let startTime = Date()
        while query.isGathering, Date().timeIntervalSince(startTime) < 2.0 {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
    }

    private func bestMatch(in query: NSMetadataQuery) -> (url: URL, score: Int)? {
        var bestMatch: (url: URL, score: Int)?
        let searchTerm = self.name.lowercased()

        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                continue
            }

            let appURL = URL(fileURLWithPath: path)
            let displayName = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String) ?? ""
            let fsName = appURL.lastPathComponent

            let spotlightMessage =
                "Spotlight found: \(path), displayName: '\(displayName)', fsName: '\(fsName)'"
            self.logger.debug("\(spotlightMessage)")

            let score = score(for: displayName, fsName: fsName, path: path, searchTerm: searchTerm)
            if score > (bestMatch?.score ?? 0) {
                bestMatch = (appURL, score)
            }

            if score >= 100 {
                break
            }
        }

        return bestMatch
    }

    private func score(
        for displayName: String,
        fsName: String,
        path: String,
        searchTerm: String) -> Int
    {
        var score = 0
        let fsNameNoExt = fsName.hasSuffix(".app") ? String(fsName.dropLast(4)) : fsName
        let displayLower = displayName.lowercased()
        let fsLower = fsNameNoExt.lowercased()

        if displayLower == searchTerm ||
            fsLower == searchTerm ||
            fsName.lowercased() == "\(searchTerm).app"
        {
            score = 100
        } else if displayLower.hasPrefix(searchTerm) || fsLower.hasPrefix(searchTerm) {
            score = 80
        } else if displayLower.contains(searchTerm) || fsLower.contains(searchTerm) {
            score = 50
        }

        if path.hasPrefix("/Applications/") {
            score += 10
        } else if path.hasPrefix("/System/Applications/") {
            score += 5
        }

        if path.contains("/DerivedData/"), path.contains("/Debug/") {
            score += 15
        }

        return score
    }
}
