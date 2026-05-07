@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
extension DockService {
    func launchFromDockImpl(appName: String) async throws {
        let dockElement = try findDockElement(appName: appName)

        _ = await self.feedbackClient.showAppLaunch(appName: appName, iconPath: nil)

        do {
            try dockElement.performAction(.press)
        } catch {
            throw PeekabooError.operationError(message: "Failed to launch '\(appName)' from Dock.")
        }

        try await Task.sleep(nanoseconds: 200_000_000)
    }

    func addToDockImpl(path: String, persistent _: Bool = true) async throws {
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let isFolder = isDirectory.boolValue
        let plistKey = isFolder ? "persistent-others" : "persistent-apps"

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
    }

    func removeFromDockImpl(appName: String) async throws {
        let appleScript = """
        on run argv
        set targetName to item 1 of argv
        tell application "System Events"
            tell process "Dock"
                set dockItems to every UI element of list 1
                repeat with dockItem in dockItems
                    if name of dockItem contains targetName then
                        perform action "AXShowMenu" of dockItem
                        delay 0.1
                        click menu item "Remove from Dock" of menu 1 of dockItem
                        return "Removed"
                    end if
                end repeat
            end tell
        end tell
        return "Not found"
        end run
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", appleScript, appName]

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
    }

    func rightClickDockItemImpl(appName: String, menuItem: String?) async throws {
        let element = try findDockElement(appName: appName)

        guard let position = element.position(),
              let size = element.size()
        else {
            throw PeekabooError.operationError(message: "Could not determine Dock item position for '\(appName)'.")
        }

        let center = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2)

        _ = await self.feedbackClient.showClickFeedback(at: center, type: .right)

        try InputDriver.click(at: center, button: .right, count: 1)
        usleep(50000)

        if let targetMenuItem = menuItem {
            try await self.clickContextMenuItem(targetMenuItem, for: element, fallbackName: appName)
        }
    }

    private func clickContextMenuItem(
        _ targetMenuItem: String,
        for dockElement: Element,
        fallbackName: String) async throws
    {
        try await Task.sleep(nanoseconds: 300_000_000)

        let menu: Element?
        if let childMenu = dockElement.children()?.first(where: { $0.role() == "AXMenu" }) {
            menu = childMenu
        } else {
            let systemWide = Element.systemWide()
            menu = systemWide.children()?.first(where: { $0.role() == "AXMenu" })
        }

        guard let foundMenu = menu else {
            throw PeekabooError.menuNotFound("\(fallbackName)")
        }

        let menuItems = foundMenu.children() ?? []
        guard let targetItem = menuItems.first(where: { item in
            item.title() == targetMenuItem ||
                item.title()?.contains(targetMenuItem) == true
        }) else {
            throw PeekabooError.menuNotFound("\(targetMenuItem)")
        }

        try targetItem.performAction(.press)
    }
}
