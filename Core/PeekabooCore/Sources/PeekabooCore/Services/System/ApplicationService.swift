import Foundation
import AppKit
import AXorcist
import os.log

/// Default implementation of application management operations
public final class ApplicationService: ApplicationServiceProtocol {
    
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ApplicationService")
    
    public init() {}
    
    public func listApplications() async throws -> [ServiceApplicationInfo] {
        logger.info("Listing all running applications")
        let runningApps = NSWorkspace.shared.runningApplications
        
        logger.debug("Found \(runningApps.count) running processes")
        
        let filteredApps: [ServiceApplicationInfo] = runningApps.compactMap { app -> ServiceApplicationInfo? in
            // Skip apps without a localized name
            guard let name = app.localizedName else { return nil }
            
            // Skip system/background apps unless they have windows
            if app.activationPolicy == .prohibited {
                return nil
            }
            
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: name,
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden,
                windowCount: 0  // Will be updated separately
            )
        }.sorted { (app1, app2) -> Bool in
            return app1.name < app2.name
        }
        
        logger.info("Returning \(filteredApps.count) visible applications")
        return filteredApps
    }
    
    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        logger.info("Finding application with identifier: \(identifier, privacy: .public)")
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Try exact bundle ID match
        if let app = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            logger.debug("Found app by bundle ID match: \(app.localizedName ?? "Unknown")")
            return createApplicationInfo(from: app)
        }
        
        // Try exact name match (case-insensitive), but prefer GUI apps
        let lowercaseIdentifier = identifier.lowercased()
        let exactMatches = runningApps.filter { 
            $0.localizedName?.lowercased() == lowercaseIdentifier 
        }
        
        if exactMatches.count == 1 {
            logger.debug("Found app by exact name match: \(exactMatches[0].localizedName ?? "Unknown", privacy: .public)")
            return createApplicationInfo(from: exactMatches[0])
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
            logger.debug("Multiple exact matches for '\(identifier, privacy: .public)', selected: \(sortedExactMatches[0].localizedName ?? "Unknown", privacy: .public) (PID: \(sortedExactMatches[0].processIdentifier, privacy: .public))")
            return createApplicationInfo(from: sortedExactMatches[0])
        }
        
        // Try fuzzy match
        let matches = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            return name.lowercased().contains(lowercaseIdentifier) ||
                   (app.bundleIdentifier?.lowercased().contains(lowercaseIdentifier) ?? false)
        }
        
        if matches.count == 1 {
            logger.debug("Found single fuzzy match: \(matches[0].localizedName ?? "Unknown")")
            return createApplicationInfo(from: matches[0])
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
            
            logger.debug("Multiple matches found for '\(identifier, privacy: .public)': \(matches.compactMap { $0.localizedName }, privacy: .public)")
            logger.debug("Selected: \(sortedMatches[0].localizedName ?? "Unknown", privacy: .public) (PID: \(sortedMatches[0].processIdentifier, privacy: .public), Bundle: \(sortedMatches[0].bundleIdentifier ?? "none", privacy: .public), Policy: \(sortedMatches[0].activationPolicy.rawValue, privacy: .public))")
            
            return createApplicationInfo(from: sortedMatches[0])
        }
        
        logger.error("Application not found: \(identifier)")
        throw NotFoundError.application(identifier)
    }
    
    @MainActor
    public func listWindows(for appIdentifier: String) async throws -> [ServiceWindowInfo] {
        logger.info("Listing windows for application: \(appIdentifier)")
        let app = try await findApplication(identifier: appIdentifier)
        
        // Get AX element for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // Get windows
        guard let axWindows = appElement.windows() else {
            return []
        }
        
        var windows: [ServiceWindowInfo] = []
        for (index, window) in axWindows.enumerated() {
            if let windowInfo = await createWindowInfo(from: window, index: index) {
                windows.append(windowInfo)
            }
        }
        
        logger.debug("Found \(windows.count) windows for \(app.name)")
        return windows
    }
    
    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        logger.info("Getting frontmost application")
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logger.error("No frontmost application found")
            throw PeekabooError.appNotFound("frontmost")
        }
        
        logger.debug("Frontmost app: \(frontmostApp.localizedName ?? "Unknown") (PID: \(frontmostApp.processIdentifier))")
        return createApplicationInfo(from: frontmostApp)
    }
    
    public func isApplicationRunning(identifier: String) async -> Bool {
        logger.debug("Checking if application is running: \(identifier)")
        do {
            _ = try await findApplication(identifier: identifier)
            logger.debug("Application is running: \(identifier)")
            return true
        } catch {
            logger.debug("Application is not running: \(identifier)")
            return false
        }
    }
    
    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        logger.info("Launching application: \(identifier)")
        
        // First check if already running
        if let existingApp = try? await findApplication(identifier: identifier) {
            logger.debug("Application already running: \(existingApp.name)")
            return existingApp
        }
        
        // Try to launch by bundle ID
        let workspace = NSWorkspace.shared
        
        // Find the app URL
        let appURL: URL
        if let url = workspace.urlForApplication(withBundleIdentifier: identifier) {
            logger.debug("Found app by bundle ID at: \(url.path)")
            appURL = url
        } else if let url = findApplicationByName(identifier) {
            logger.debug("Found app by name at: \(url.path)")
            appURL = url
        } else {
            logger.error("Application not found in system: \(identifier)")
            throw PeekabooError.appNotFound(identifier)
        }
        
        // Launch the application
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        logger.debug("Launching app from URL: \(appURL.path)")
        let runningApp = try await workspace.openApplication(at: appURL, configuration: config)
        
        // Wait a bit for the app to fully launch
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        logger.info("Successfully launched: \(runningApp.localizedName ?? "Unknown") (PID: \(runningApp.processIdentifier))")
        return createApplicationInfo(from: runningApp)
    }
    
    public func activateApplication(identifier: String) async throws {
        logger.info("Activating application: \(identifier)")
        let app = try await findApplication(identifier: identifier)
        
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw PeekabooError.operationError(
                message: "Failed to activate application: Could not find running application process"
            )
        }
        
        let activated = runningApp.activate(options: [])
        
        if !activated {
            logger.error("Failed to activate application: \(app.name)")
            throw PeekabooError.operationError(
                message: "Failed to activate application: Application failed to activate"
            )
        }
        
        logger.info("Successfully activated: \(app.name)")
        // Wait for activation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    public func quitApplication(identifier: String, force: Bool = false) async throws -> Bool {
        logger.info("Quitting application: \(identifier) (force: \(force))")
        let app = try await findApplication(identifier: identifier)
        
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw PeekabooError.appNotFound(identifier)
        }
        
        logger.debug("Sending \(force ? "force terminate" : "terminate") signal to \(app.name)")
        let success = force ? runningApp.forceTerminate() : runningApp.terminate()
        
        // Wait a bit for the termination to complete
        if success {
            logger.info("Successfully quit: \(app.name)")
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        } else {
            logger.error("Failed to quit: \(app.name)")
        }
        
        return success
    }
    
    public func hideApplication(identifier: String) async throws {
        logger.info("Hiding application: \(identifier)")
        let app = try await findApplication(identifier: identifier)
        
        await MainActor.run {
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
                if let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) {
                    runningApp.hide()
                    self.logger.debug("Hidden via NSRunningApplication: \(app.name)")
                }
            }
        }
    }
    
    public func unhideApplication(identifier: String) async throws {
        logger.info("Unhiding application: \(identifier)")
        let app = try await findApplication(identifier: identifier)
        
        await MainActor.run {
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
                if let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) {
                    runningApp.activate()
                    self.logger.debug("Activated as fallback: \(app.name)")
                }
            }
        }
    }
    
    public func hideOtherApplications(identifier: String) async throws {
        logger.info("Hiding other applications except: \(identifier)")
        let app = try await findApplication(identifier: identifier)
        
        await MainActor.run {
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
                let workspace = NSWorkspace.shared
                var hiddenCount = 0
                for runningApp in workspace.runningApplications {
                    if runningApp.processIdentifier != app.processIdentifier &&
                       runningApp.activationPolicy == .regular &&
                       runningApp.bundleIdentifier != "com.apple.finder" {
                        runningApp.hide()
                        hiddenCount += 1
                    }
                }
                self.logger.debug("Hidden \(hiddenCount) other applications")
            }
        }
    }
    
    public func showAllApplications() async throws {
        logger.info("Showing all applications")
        await MainActor.run {
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
                let workspace = NSWorkspace.shared
                var unhiddenCount = 0
                for runningApp in workspace.runningApplications {
                    if runningApp.isHidden && runningApp.activationPolicy == .regular {
                        runningApp.unhide()
                        unhiddenCount += 1
                    }
                }
                self.logger.debug("Unhidden \(unhiddenCount) applications")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func createApplicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        return ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: getWindowCount(for: app)
        )
    }
    
    @MainActor
    private func createWindowInfo(from window: Element, index: Int) async -> ServiceWindowInfo? {
        guard let title = window.title() else { return nil }
        
        let position = window.position() ?? .zero
        let size = window.size() ?? .zero
        let bounds = CGRect(origin: position, size: size)
        
        let isMinimized = window.isMinimized() ?? false
        let isMain = window.isMain() ?? false
        
        // Try to get the actual CGWindowID
        let windowIdentityService = WindowIdentityService()
        let windowID = windowIdentityService.getWindowID(from: window) ?? CGWindowID(index)
        
        // Get space information for the window
        let (spaceID, spaceName) = getSpaceInfo(for: windowID)
        
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
            spaceName: spaceName
        )
    }
    
    @MainActor
    private func getSpaceInfo(for windowID: CGWindowID) -> (spaceID: UInt64?, spaceName: String?) {
        let spaceService = SpaceManagementService()
        let spaces = spaceService.getSpacesForWindow(windowID: windowID)
        
        // Return the first space the window is on (windows can technically be on multiple spaces)
        if let firstSpace = spaces.first {
            return (firstSpace.id, firstSpace.name)
        }
        
        return (nil, nil)
    }
    
    private func getWindowCount(for app: NSRunningApplication) -> Int {
        // For now, return 0 - getting accurate window count requires MainActor
        // This will be populated when windows are actually queried
        return 0
    }
    
    private func findApplicationByName(_ name: String) -> URL? {
        logger.debug("Searching for application by name: \(name)")
        let workspace = NSWorkspace.shared
        
        // Common application directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "~/Applications"
        ].map { NSString(string: $0).expandingTildeInPath }
        
        let fileManager = FileManager.default
        
        for path in searchPaths {
            let searchName = name.hasSuffix(".app") ? name : "\(name).app"
            let fullPath = (path as NSString).appendingPathComponent(searchName)
            
            if fileManager.fileExists(atPath: fullPath) {
                logger.debug("Found app at: \(fullPath)")
                return URL(fileURLWithPath: fullPath)
            }
        }
        
        // Try Spotlight as last resort
        if let url = workspace.urlForApplication(withBundleIdentifier: name) {
            logger.debug("Found app via Spotlight: \(url.path)")
            return url
        }
        
        logger.debug("Application not found by name: \(name)")
        return nil
    }
}