import AppKit
import AXorcist
import Foundation
import os.log

/// Default implementation of application management operations
@MainActor
public final class ApplicationService: ApplicationServiceProtocol {
    internal let logger = Logger(subsystem: "boo.peekaboo.core", category: "ApplicationService")
    
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
        let isMacApp = Bundle.main.bundleIdentifier == "boo.peekaboo.mac"
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

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

    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        self.logger.info("Finding application with identifier: \(identifier, privacy: .public)")

        // Already on main thread due to @MainActor on class
        let runningApps = NSWorkspace.shared.runningApplications

        // Check for PID format first
        if identifier.hasPrefix("PID:") {
            let pidString = String(identifier.dropFirst(4))
            if let pid = Int32(pidString) {
                // Create NSRunningApplication
                let app = NSRunningApplication(processIdentifier: pid)
                if let app, !app.isTerminated {
                    self.logger.debug("Found app by PID: \(pid)")
                    return self.createApplicationInfo(from: app)
                } else {
                    throw PeekabooError.appNotFound("Process with PID \(pidString) not found or terminated")
                }
            } else {
                throw PeekabooError.appNotFound("Invalid PID format: \(pidString)")
            }
        }

        // Try exact bundle ID match
        if let app = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            self.logger.debug("Found app by bundle ID match: \(app.localizedName ?? "Unknown")")
            return self.createApplicationInfo(from: app)
        }

        // Try exact name match (case-insensitive), but prefer GUI apps
        let lowercaseIdentifier = identifier.lowercased()

        let exactMatches = runningApps.filter {
            $0.localizedName?.lowercased() == lowercaseIdentifier
        }

        if exactMatches.count == 1 {
            self.logger
                .debug("Found app by exact name match: \(exactMatches[0].localizedName ?? "Unknown", privacy: .public)")
            return self.createApplicationInfo(from: exactMatches[0])
        } else if exactMatches.count > 1 {
            // Multiple exact matches - prefer GUI apps
            let sortedExactMatches = exactMatches.sorted { app1, app2 in
                // GUI apps come first
                let app1IsGUI = app1.activationPolicy != .prohibited
                let app2IsGUI = app2.activationPolicy != .prohibited
                if app1IsGUI != app2IsGUI {
                    return app1IsGUI
                }
                // Then apps with bundle IDs
                let app1HasBundle = app1.bundleIdentifier != nil
                let app2HasBundle = app2.bundleIdentifier != nil
                if app1HasBundle != app2HasBundle {
                    return app1HasBundle
                }
                return false
            }
            self.logger
                .debug(
                    "Multiple exact matches for '\(identifier, privacy: .public)', selected: \(sortedExactMatches[0].localizedName ?? "Unknown", privacy: .public) (PID: \(sortedExactMatches[0].processIdentifier, privacy: .public))")
            return self.createApplicationInfo(from: sortedExactMatches[0])
        }

        // Try fuzzy match
        let matches = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            return name.lowercased().contains(lowercaseIdentifier) ||
                (app.bundleIdentifier?.lowercased().contains(lowercaseIdentifier) ?? false)
        }

        if matches.count == 1 {
            self.logger.debug("Found single fuzzy match: \(matches[0].localizedName ?? "Unknown")")
            return self.createApplicationInfo(from: matches[0])
        } else if matches.count > 1 {
            // Sort matches by priority:
            // 1. GUI apps (regular or accessory) over prohibited (background/CLI)
            // 2. Apps with bundle identifiers over those without
            // 3. Active apps over inactive
            let sortedMatches = matches.sorted { app1, app2 in
                // First priority: GUI apps
                let app1IsGUI = app1.activationPolicy != .prohibited
                let app2IsGUI = app2.activationPolicy != .prohibited
                if app1IsGUI != app2IsGUI {
                    return app1IsGUI // GUI apps come first
                }

                // Second priority: Has bundle identifier
                let app1HasBundle = app1.bundleIdentifier != nil
                let app2HasBundle = app2.bundleIdentifier != nil
                if app1HasBundle != app2HasBundle {
                    return app1HasBundle
                }

                // Third priority: Active state
                if app1.isActive != app2.isActive {
                    return app1.isActive
                }

                return false // Keep original order if all else equal
            }

            self.logger
                .debug(
                    "Multiple matches found for '\(identifier, privacy: .public)': \(matches.compactMap { $0.localizedName }, privacy: .public)")
            let selected = sortedMatches[0]
            let selectedName = selected.localizedName ?? "Unknown"
            let selectedBundle = selected.bundleIdentifier ?? "none"
            let selectedPID = selected.processIdentifier
            let selectedPolicy = selected.activationPolicy.rawValue
            
            // Break up the expression to help the compiler
            let message = "Selected: \(selectedName) (PID: \(selectedPID), Bundle: \(selectedBundle), Policy: \(selectedPolicy))"
            self.logger.debug("\(message, privacy: .public)")

            return self.createApplicationInfo(from: sortedMatches[0])
        }

        self.logger.error("Application not found: \(identifier)")
        throw NotFoundError.application(identifier)
    }

    public func listWindows(for appIdentifier: String, timeout: Float? = nil) async throws -> UnifiedToolOutput<ServiceWindowListData> {
        let startTime = Date()
        self.logger.info("Listing windows for application: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)
        
        // Use provided timeout or default
        let axTimeout = timeout ?? Self.axTimeout
        
        // Check if we have screen recording permission
        let hasScreenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        
        // First, try CGWindowList for fast window discovery (if we have permission)
        var cgWindows: [ServiceWindowInfo] = []
        var cgWindowsByTitle: [String: ServiceWindowInfo] = [:]
        
        if hasScreenRecording {
            self.logger.debug("Using hybrid approach: CGWindowList + selective AX enrichment")
            
            // Get windows using CGWindowList API (fast, doesn't hang)
            let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
            if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                var windowIndex = 0
                
                for windowInfo in windowList {
                    // Check if window belongs to our app
                    guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                          ownerPID == app.processIdentifier else {
                        continue
                    }
                    
                    // Get basic window info from CGWindowList
                    guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                          let x = boundsDict["X"] as? CGFloat,
                          let y = boundsDict["Y"] as? CGFloat,
                          let width = boundsDict["Width"] as? CGFloat,
                          let height = boundsDict["Height"] as? CGFloat else {
                        continue
                    }
                    
                    let bounds = CGRect(x: x, y: y, width: width, height: height)
                    let windowID = windowInfo[kCGWindowNumber as String] as? Int ?? windowIndex
                    let windowLevel = windowInfo[kCGWindowLayer as String] as? Int ?? 0
                    let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
                    
                    // Window title might be missing without screen recording
                    let windowTitle = windowInfo[kCGWindowName as String] as? String
                    
                    // Skip windows without titles unless we'll enrich them
                    if windowTitle == nil || windowTitle!.isEmpty {
                        self.logger.debug("Window \(windowID) has no title in CGWindowList, will need AX enrichment")
                    }
                    
                    // Determine if minimized based on bounds
                    let isMinimized = bounds.origin.x < -10000 || bounds.origin.y < -10000
                    let isOffScreen = !NSScreen.screens.contains { screen in
                        screen.frame.intersects(bounds)
                    }
                    
                    // Get space information
                    let spaceService = SpaceManagementService()
                    let spaces = spaceService.getSpacesForWindow(windowID: CGWindowID(windowID))
                    let (spaceID, spaceName) = spaces.first.map { ($0.id, $0.name) } ?? (nil, nil)
                    
                    // Detect which screen this window is on
                    let screenService = ScreenService()
                    let screenInfo = screenService.screenContainingWindow(bounds: bounds)
                    
                    let cgWindowInfo = ServiceWindowInfo(
                        windowID: windowID,
                        title: windowTitle ?? "",  // Empty title if missing
                        bounds: bounds,
                        isMinimized: isMinimized,
                        isMainWindow: windowIndex == 0,
                        windowLevel: windowLevel,
                        alpha: alpha,
                        index: windowIndex,
                        spaceID: spaceID,
                        spaceName: spaceName,
                        screenIndex: screenInfo?.index,
                        screenName: screenInfo?.name
                    )
                    
                    cgWindows.append(cgWindowInfo)
                    if let title = windowTitle, !title.isEmpty {
                        cgWindowsByTitle[title] = cgWindowInfo
                    }
                    windowIndex += 1
                }
                
                self.logger.debug("CGWindowList found \(cgWindows.count) windows for \(app.name)")
            }
        }
        
        // If we got complete window info from CGWindowList, use it
        if !cgWindows.isEmpty && cgWindows.allSatisfy({ !$0.title.isEmpty }) {
            self.logger.debug("All windows have titles from CGWindowList, using fast path")
            return self.buildWindowListOutput(
                windows: cgWindows,
                app: app,
                startTime: startTime,
                warnings: []
            )
        }
        
        // Otherwise, we need to use AX API (with timeout protection) to get missing titles
        self.logger.debug("Need to enrich window data with AX API (missing titles or no screen recording)")
        
        // Defensive: Check if the app is still running before accessing AX
        guard NSRunningApplication(processIdentifier: app.processIdentifier)?.isTerminated == false else {
            self.logger.warning("Application \(app.name) appears to have terminated")
            return UnifiedToolOutput(
                data: ServiceWindowListData(windows: [], targetApplication: app),
                summary: UnifiedToolOutput.Summary(
                    brief: "Application \(app.name) has no windows (app terminated)",
                    status: .failed,
                    counts: ["windows": 0]),
                metadata: UnifiedToolOutput.Metadata(
                    duration: Date().timeIntervalSince(startTime),
                    warnings: ["Application appears to have terminated"]))
        }
        
        // Get AX element for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // Set timeout for this operation
        appElement.setMessagingTimeout(axTimeout)
        defer { appElement.setMessagingTimeout(0) }
        
        // Get windows with timeout protection
        let windowStartTime = Date()
        let allWindows = appElement.windowsWithTimeout(timeout: axTimeout) ?? []
        
        // Check if operation timed out
        let timedOut = Date().timeIntervalSince(windowStartTime) >= Double(axTimeout)
        
        // If we have CGWindowList data, merge it with AX data
        if !cgWindows.isEmpty {
            var enrichedWindows: [ServiceWindowInfo] = []
            var warnings: [String] = []
            
            // Process AX windows to enrich CGWindowList data
            for (index, axWindow) in allWindows.enumerated() {
                // Stop if we're taking too long
                if Date().timeIntervalSince(startTime) > Double(axTimeout * 2) {
                    warnings.append("Stopped enrichment after timeout")
                    break
                }
                
                // Get title from AX
                guard let axTitle = axWindow.title(), !axTitle.isEmpty else {
                    continue
                }
                
                // Try to match with CGWindowList data
                if let cgWindow = cgWindowsByTitle[axTitle] {
                    // Already have complete data from CGWindowList
                    enrichedWindows.append(cgWindow)
                } else {
                    // Need to create window info from AX
                    if let windowInfo = await createWindowInfo(from: axWindow, index: index) {
                        enrichedWindows.append(windowInfo)
                    }
                }
            }
            
            // Add any CG windows we didn't match (might have empty titles)
            for cgWindow in cgWindows {
                if !enrichedWindows.contains(where: { $0.windowID == cgWindow.windowID }) {
                    if cgWindow.title.isEmpty {
                        // Try to find a title from unmatched AX windows
                        // This is best-effort since we can't reliably match without titles
                        self.logger.debug("CGWindow \(cgWindow.windowID) has no title, including as-is")
                    }
                    enrichedWindows.append(cgWindow)
                }
            }
            
            if timedOut {
                warnings.append("Window enumeration timed out after \(axTimeout)s, results may be incomplete")
            }
            
            return self.buildWindowListOutput(
                windows: enrichedWindows,
                app: app,
                startTime: startTime,
                warnings: warnings
            )
        }
        
        // Fallback: Pure AX approach (no screen recording permission)
        self.logger.debug("Using pure AX approach (no screen recording permission)")
        
        // Limit windows as protection
        let maxWindowsToProcess = 100
        let windows = Array(allWindows.prefix(maxWindowsToProcess))
        
        if allWindows.count > maxWindowsToProcess {
            self.logger.warning("Application \(app.name) has \(allWindows.count) windows, processing only first \(maxWindowsToProcess)")
        }
        
        var windowInfos: [ServiceWindowInfo] = []
        var warnings: [String] = []
        
        // Process windows with timeout check
        for (index, window) in windows.enumerated() {
            // Skip processing if we've exceeded timeout
            if Date().timeIntervalSince(startTime) > Double(axTimeout) {
                warnings.append("Stopped processing after \(axTimeout)s timeout")
                break
            }
            
            if let windowInfo = await createWindowInfo(from: window, index: index) {
                windowInfos.append(windowInfo)
            }
        }
        
        if timedOut {
            warnings.append("Window enumeration timed out, results may be incomplete")
        }
        
        if allWindows.count > maxWindowsToProcess {
            warnings.append("Only processed first \(maxWindowsToProcess) of \(allWindows.count) windows")
        }
        
        if !hasScreenRecording {
            warnings.append("Screen recording permission not granted - window listing may be slower")
        }
        
        return self.buildWindowListOutput(
            windows: windowInfos,
            app: app,
            startTime: startTime,
            warnings: warnings
        )
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

        self.logger
            .info(
                "Successfully launched: \(runningApp.localizedName ?? "Unknown") (PID: \(runningApp.processIdentifier))")
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
            self.logger.error("Failed to activate application: \(app.name)")
            throw PeekabooError.operationError(
                message: "Failed to activate application: Application failed to activate")
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

    // MARK: - Private Helpers

    @MainActor
    private func createApplicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: 0 // Don't query window count by default for performance
        )
    }

    private func createWindowInfo(from window: Element, index: Int) async -> ServiceWindowInfo? {
        guard let title = window.title() else { return nil }

        let position = window.position() ?? .zero
        let size = window.size() ?? .zero
        let bounds = CGRect(origin: position, size: size)

        let isMinimized = window.isMinimized() ?? false
        let isMain = window.isMain() ?? false
        
        // Detect which screen this window is on
        let screenService = ScreenService()
        let screenInfo = screenService.screenContainingWindow(bounds: bounds)
        let screenIndex = screenInfo?.index
        let screenName = screenInfo?.name

        // Try to get the actual CGWindowID
        let windowIdentityService = WindowIdentityService()
        var actualWindowID = windowIdentityService.getWindowID(from: window)

        // If private API fails, try to find window by matching title and bounds
        if actualWindowID == nil, let pid = window.pid() {
            // Use CGWindowListCopyWindowInfo to find windows for this PID
            let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
            if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                for windowInfo in windowList {
                    // Match by PID, title, and bounds
                    if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                       ownerPID == pid,
                       let windowTitle = windowInfo[kCGWindowName as String] as? String,
                       windowTitle == title,
                       let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                       let x = boundsDict["X"] as? CGFloat,
                       let y = boundsDict["Y"] as? CGFloat,
                       let width = boundsDict["Width"] as? CGFloat,
                       let height = boundsDict["Height"] as? CGFloat
                    {
                        let cgBounds = CGRect(x: x, y: y, width: width, height: height)
                        // Allow small differences due to coordinate system conversions
                        if abs(cgBounds.origin.x - bounds.origin.x) < 5,
                           abs(cgBounds.origin.y - bounds.origin.y) < 5,
                           abs(cgBounds.size.width - bounds.size.width) < 5,
                           abs(cgBounds.size.height - bounds.size.height) < 5
                        {
                            if let windowNumber = windowInfo[kCGWindowNumber as String] as? Int {
                                actualWindowID = CGWindowID(windowNumber)
                                self.logger.debug("Found window ID \(windowNumber) via CGWindowList for '\(title)'")
                                break
                            }
                        }
                    }
                }
            }
        }

        // Use actual window ID if available, otherwise use index
        let windowID = actualWindowID ?? CGWindowID(index)

        // Debug logging
        if actualWindowID == nil {
            self.logger
                .warning("Failed to get actual window ID for window '\(title)', using index \(index) as fallback")
        }

        // Get space information for the window
        let (spaceID, spaceName) = self.getSpaceInfo(for: windowID)

        // Get window level (z-order) from CGS
        let spaceService = SpaceManagementService()
        let windowLevel = spaceService.getWindowLevel(windowID: windowID).map { Int($0) } ?? 0

        return ServiceWindowInfo(
            windowID: Int(windowID), // Convert CGWindowID to Int
            title: title,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: isMain,
            windowLevel: windowLevel,
            index: index,
            spaceID: spaceID,
            spaceName: spaceName,
            screenIndex: screenIndex,
            screenName: screenName)
    }

    private func getSpaceInfo(for windowID: CGWindowID) -> (spaceID: UInt64?, spaceName: String?) {
        let spaceService = SpaceManagementService()
        let spaces = spaceService.getSpacesForWindow(windowID: windowID)

        // Return the first space the window is on (windows can technically be on multiple spaces)
        if let firstSpace = spaces.first {
            return (firstSpace.id, firstSpace.name)
        }

        return (nil, nil)
    }

    @MainActor
    private func getWindowCount(for app: NSRunningApplication) -> Int {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        return appElement.windows()?.count ?? 0
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
        self.logger.debug("Using Spotlight to search for: \(name)")

        // Create metadata query for applications
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "(kMDItemContentType == 'com.apple.application-bundle' || kMDItemContentType == 'com.apple.application') && (kMDItemDisplayName CONTAINS[cd] %@ || kMDItemFSName CONTAINS[cd] %@)",
            name, name)
        query.searchScopes = [
            NSMetadataQueryIndexedLocalComputerScope,
            NSMetadataQueryIndexedNetworkScope,
        ]

        // Start query synchronously
        query.start()

        // Wait for results (with timeout)
        let startTime = Date()
        while query.isGathering, Date().timeIntervalSince(startTime) < 2.0 {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        query.stop()

        self.logger.debug("Spotlight query completed with \(query.resultCount) results")

        // Process results
        var bestMatch: URL?
        var bestScore = 0

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                continue
            }

            let appURL = URL(fileURLWithPath: path)
            let displayName = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String) ?? ""
            let fsName = appURL.lastPathComponent

            self.logger.debug("Spotlight found: \(path), displayName: '\(displayName)', fsName: '\(fsName)'")

            // Score based on match quality
            var score = 0

            // Remove .app extension for comparison
            let fsNameNoExt = fsName.hasSuffix(".app") ? String(fsName.dropLast(4)) : fsName

            // Exact match (case insensitive)
            if displayName.lowercased() == name.lowercased() ||
                fsNameNoExt.lowercased() == name.lowercased() ||
                fsName.lowercased() == "\(name.lowercased()).app"
            {
                score = 100
            }
            // Starts with search term
            else if displayName.lowercased().hasPrefix(name.lowercased()) ||
                fsNameNoExt.lowercased().hasPrefix(name.lowercased())
            {
                score = 80
            }
            // Contains search term
            else if displayName.lowercased().contains(name.lowercased()) ||
                fsNameNoExt.lowercased().contains(name.lowercased())
            {
                score = 50
            }

            // Prefer apps in standard locations
            if path.hasPrefix("/Applications/") {
                score += 10
            } else if path.hasPrefix("/System/Applications/") {
                score += 5
            }

            // Prefer apps in DerivedData for debug builds
            if path.contains("/DerivedData/"), path.contains("/Debug/") {
                score += 15 // Higher priority for debug builds when explicitly searching
            }

            if score > bestScore {
                bestScore = score
                bestMatch = appURL
            }

            // If we found an exact match, we can stop
            if score >= 100 {
                break
            }
        }

        if let match = bestMatch {
            self.logger.debug("Spotlight found app: \(match.path) (score: \(bestScore))")
        }

        return bestMatch
    }
    
    // MARK: - Helper for building window list output
    
    private func buildWindowListOutput(
        windows: [ServiceWindowInfo],
        app: ServiceApplicationInfo,
        startTime: Date,
        warnings: [String]
    ) -> UnifiedToolOutput<ServiceWindowListData> {
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
                    "offScreen": offScreenCount
                ],
                highlights: highlights),
            metadata: UnifiedToolOutput.Metadata(
                duration: Date().timeIntervalSince(startTime),
                warnings: warnings,
                hints: ["Use window title or index to target specific window"]))
    }
}
