import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os
import PeekabooFoundation

/// Dock-specific errors
public enum DockError: Error {
    case dockNotFound
    case dockListNotFound
    case itemNotFound(String)
    case menuItemNotFound(String)
    case positionNotFound
    case launchFailed(String)
    case scriptError(String)
}

/// Default implementation of Dock interaction operations using AXorcist
@MainActor
public final class DockService: DockServiceProtocol {
    private let feedbackClient: any AutomationFeedbackClient
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "DockService")

    public init(feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient()) {
        self.feedbackClient = feedbackClient
        Task { @MainActor in
            self.feedbackClient.connect()
        }
    }

    public func listDockItems(includeAll: Bool = false) async throws -> [DockItem] {
        // Find Dock application
        guard let dock = findDockApplication() else {
            throw PeekabooError.operationError(message: "Dock application not found or not running.")
        }

        // Get Dock items list
        guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
            throw PeekabooError.operationError(message: "Dock item list not found.")
        }

        let dockElements = dockList.children() ?? []
        var items: [DockItem] = []

        for (index, element) in dockElements.indexed() {
            guard let item = self.makeDockItem(from: element, index: index, includeAll: includeAll) else {
                continue
            }
            items.append(item)
        }

        return items
    }

    public func launchFromDock(appName: String) async throws {
        // Find the Dock item
        let dockElement = try findDockElement(appName: appName)

        // Show app launch visualization
        _ = await self.feedbackClient.showAppLaunch(appName: appName, iconPath: nil)

        // Click the item to launch
        do {
            try dockElement.performAction(.press)
        } catch {
            throw PeekabooError.operationError(message: "Failed to launch '\(appName)' from Dock.")
        }

        // Wait a bit for the launch to initiate
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    }

    private func makeDockItem(from element: Element, index: Int, includeAll: Bool) -> DockItem? {
        let role = element.role() ?? ""
        let title = element.title() ?? ""
        let subrole = element.subrole() ?? ""

        let itemType = self.determineItemType(role: role, subrole: subrole, title: title)
        if itemType == .separator, !includeAll {
            return nil
        }

        let position = element.position()
        let size = element.size()

        var isRunning: Bool?
        if itemType == .application {
            isRunning = element.attribute(Attribute<Bool>("AXIsApplicationRunning"))
        }

        let bundleIdentifier: String? = if itemType == .application, !title.isEmpty {
            self.findBundleIdentifier(for: title)
        } else {
            nil
        }

        return DockItem(
            index: index,
            title: title,
            itemType: itemType,
            isRunning: isRunning,
            bundleIdentifier: bundleIdentifier,
            position: position,
            size: size)
    }

    private func determineItemType(role: String, subrole: String, title: String) -> DockItemType {
        if role == "AXSeparator" || subrole == "AXSeparator" {
            return .separator
        }
        switch subrole {
        case "AXApplicationDockItem":
            return .application
        case "AXFolderDockItem":
            return .folder
        case "AXFileDockItem":
            return .file
        case "AXURLDockItem":
            return .url
        case "AXMinimizedWindowDockItem":
            return .minimizedWindow
        default:
            break
        }

        let normalizedTitle = title.lowercased()
        if normalizedTitle == "trash" || normalizedTitle == "bin" {
            return .trash
        }
        return .unknown
    }

    public func addToDock(path: String, persistent: Bool = true) async throws {
        // Adding to Dock

        // Determine the plist key based on item type
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let isFolder = isDirectory.boolValue
        let plistKey = isFolder ? "persistent-others" : "persistent-apps"

        // Create the dock item dictionary structure
        let tileData = """
        <dict>
            <key>tile-data</key>
            <dict>
                <key>file-data</key>
                <dict>
                    <key>_CFURLString</key>
                    <string>\(path)</string>
                    <key>_CFURLStringType</key>
                    <integer>0</integer>
                </dict>
            </dict>
        </dict>
        """

        // Use defaults command to add the item
        let script = """
        defaults write com.apple.dock \(plistKey) -array-add '\(tileData)'
        killall Dock
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PeekabooError.operationError(message: "Failed to add item to Dock: \(errorString)")
        }

        // Successfully added to Dock
    }

    public func removeFromDock(appName: String) async throws {
        // Removing app from Dock

        // Read current dock preferences
        let readScript = """
        defaults read com.apple.dock persistent-apps
        """

        let readProcess = Process()
        readProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        readProcess.arguments = ["-c", readScript]

        let outputPipe = Pipe()
        readProcess.standardOutput = outputPipe

        try readProcess.run()
        readProcess.waitUntilExit()

        _ = outputPipe.fileHandleForReading.readDataToEndOfFile()

        // Parse and filter out the target app
        // This is complex with defaults command, so we'll use a different approach:
        // Use AppleScript to remove the item
        let appleScript = """
        tell application "System Events"
            tell process "Dock"
                set dockItems to every UI element of list 1
                repeat with dockItem in dockItems
                    if name of dockItem contains "\(appName)" then
                        perform action "AXShowMenu" of dockItem
                        delay 0.1
                        click menu item "Remove from Dock" of menu 1 of dockItem
                        return "Removed"
                    end if
                end repeat
            end tell
        end tell
        return "Not found"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", appleScript]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if result == "Not found" {
            throw PeekabooError.elementNotFound("App '\(appName)' not found in Dock")
        }

        // Successfully removed from Dock
    }

    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        // Find the Dock item and get position
        let element = try findDockElement(appName: appName)

        // Get item position and size
        guard let position = element.position(),
              let size = element.size()
        else {
            throw PeekabooError.operationError(message: "Could not determine Dock item position for '\(appName)'.")
        }

        let center = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2)

        let dockElement = element

        // Show right-click feedback
        _ = await self.feedbackClient.showClickFeedback(at: center, type: .right)

        // Perform right-click
        try InputDriver.click(at: center, button: .right, count: 1)
        usleep(50000) // 50ms

        // If menu item specified, wait for menu and click it
        if let targetMenuItem = menuItem {
            // Wait for context menu to appear
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms

            // Find and click the menu item
            // Find the menu - it might be a child of the dock item or a system-wide menu
            var menu: Element?

            // First check if menu is a child of the dock item
            if let childMenu = dockElement.children()?.first(where: { $0.role() == "AXMenu" }) {
                menu = childMenu
            } else {
                // Look for system-wide menus that might have appeared
                let systemWide = Element.systemWide()
                if let systemMenus = systemWide.children()?.filter({ $0.role() == "AXMenu" }),
                   let contextMenu = systemMenus.first
                {
                    menu = contextMenu
                }
            }

            if let foundMenu = menu {
                let menuItems = foundMenu.children() ?? []
                guard let targetItem = menuItems.first(where: { item in
                    item.title() == targetMenuItem ||
                        item.title()?.contains(targetMenuItem) == true
                }) else {
                    throw PeekabooError.menuNotFound("\(targetMenuItem)")
                }

                try targetItem.performAction(.press)
            } else {
                // If we can't find the menu, throw an error
                throw PeekabooError.menuNotFound("\(appName)")
            }
        }
    }

    public func hideDock() async throws {
        if await self.isDockAutoHidden() {
            return
        }
        try await self.setDockAutohide(true)
    }

    public func showDock() async throws {
        if await !(self.isDockAutoHidden()) {
            return
        }
        try await self.setDockAutohide(false)
    }

    public func isDockAutoHidden() async -> Bool {
        do {
            let output = try await self.runCommand(
                "/usr/bin/defaults",
                arguments: ["read", "com.apple.dock", "autohide"],
                captureOutput: true)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed == "1" || trimmed == "true"
        } catch {
            // Default to false if we can't determine the state
            return false
        }
    }

    public func findDockItem(name: String) async throws -> DockItem {
        let items = try await listDockItems(includeAll: false)

        // Try exact match first
        if let exactMatch = items.first(where: { $0.title == name }) {
            return exactMatch
        }

        // Try case-insensitive match
        let lowercaseName = name.lowercased()
        if let caseMatch = items.first(where: { $0.title.lowercased() == lowercaseName }) {
            return caseMatch
        }

        // Try partial match
        let partialMatches = items.filter { item in
            item.title.lowercased().contains(lowercaseName)
        }

        if partialMatches.count == 1 {
            return partialMatches[0]
        } else if partialMatches.count > 1 {
            // Prefer running applications in case of multiple matches
            if let runningMatch = partialMatches.first(where: { $0.isRunning == true }) {
                return runningMatch
            }
            // Otherwise return the first match
            return partialMatches[0]
        }

        throw PeekabooError.elementNotFound("\(name)")
    }

    // MARK: - Private Helpers

    @MainActor
    private func findDockApplication() -> Element? {
        let workspace = NSWorkspace.shared
        guard let dockApp = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            return nil
        }

        return AXApp(dockApp).element
    }

    @MainActor
    private func findDockElement(appName: String) throws -> Element {
        guard let dock = findDockApplication() else {
            throw DockError.dockNotFound
        }

        guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
            throw DockError.dockListNotFound
        }

        let dockItems = dockList.children() ?? []

        // Try exact match first
        if let exactMatch = dockItems.first(where: { $0.title() == appName }) {
            return exactMatch
        }

        // Try case-insensitive partial match
        let lowercaseAppName = appName.lowercased()
        if let match = dockItems.first(where: { item in
            guard let title = item.title() else { return false }
            return title.lowercased() == lowercaseAppName ||
                title.lowercased().contains(lowercaseAppName)
        }) {
            return match
        }

        throw DockError.itemNotFound(appName)
    }

    private func findBundleIdentifier(for appName: String) -> String? {
        // Try to find the bundle identifier for a given app name
        let workspace = NSWorkspace.shared

        // Check running applications first
        if let runningApp = workspace.runningApplications.first(where: {
            $0.localizedName == appName || $0.localizedName?.contains(appName) == true
        }) {
            return runningApp.bundleIdentifier
        }

        // Try to find in common application directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "~/Applications",
        ].map { NSString(string: $0).expandingTildeInPath }

        let fileManager = FileManager.default

        for path in searchPaths {
            let searchName = appName.hasSuffix(".app") ? appName : "\(appName).app"
            let fullPath = (path as NSString).appendingPathComponent(searchName)

            if fileManager.fileExists(atPath: fullPath) {
                if let bundle = Bundle(path: fullPath) {
                    return bundle.bundleIdentifier
                }
            }
        }

        return nil
    }

    private func setDockAutohide(_ enabled: Bool) async throws {
        let boolFlag = enabled ? "true" : "false"
        _ = try await self.runCommand(
            "/usr/bin/defaults",
            arguments: ["write", "com.apple.dock", "autohide", "-bool", boolFlag])
        _ = try await self.runCommand("/usr/bin/killall", arguments: ["Dock"])
    }

    private func runCommand(
        _ launchPath: String,
        arguments: [String],
        captureOutput: Bool = false) async throws -> String
    {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments

                let pipe = Pipe()
                if captureOutput {
                    process.standardOutput = pipe
                }
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let error = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: PeekabooError
                        .operationError(message: "Command execution failed: \(error)"))
                } else if captureOutput {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(returning: "")
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
