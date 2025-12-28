import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Command for interacting with macOS menu bar items (status items).
@MainActor
struct MenuBarCommand: ParsableCommand, OutputFormattable {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "menubar",
                abstract: "Interact with macOS menu bar items (status items)",
                discussion: """
                The menubar command provides specialized support for interacting with menu bar items
                (also known as status items) on macOS. These are the icons that appear on the right
                side of the menu bar.

                FEATURES:
                  • Fuzzy matching - Partial text and case-insensitive search
                  • Index-based clicking - Use item number from list output
                  • Smart error messages - Shows available items when not found
                  • JSON output support - For scripting and automation

                EXAMPLES:
                  # List all menu bar items with indices
                  peekaboo menubar list
                  peekaboo menubar list --json-output      # JSON format

                  # Click by exact or partial name (case-insensitive)
                  peekaboo menubar click "Wi-Fi"           # Exact match
                  peekaboo menubar click "wi"              # Partial match
                  peekaboo menubar click "Bluetooth"       # Click Bluetooth icon

                  # Click by index from the list
                  peekaboo menubar click --index 3         # Click the 3rd item

                NOTE: Menu bar items are different from regular application menus. For application
                menus (File, Edit, etc.), use the 'menu' command instead.
                """,
                showHelpOnEmptyInvocation: true
            )
        }
    }

    @Argument(help: "Action to perform (list or click)")
    var action: String

    @Argument(help: "Name of the menu bar item to click (for click action)")
    var itemName: String?

    @Option(help: "Index of the menu bar item (0-based)")
    var index: Int?

    @Flag(help: "Include raw debug fields (window owner/layer) in JSON output")
    var includeRawDebug: Bool = false

    @Flag(help: "Verify the click by checking for a matching popover window")
    var verify: Bool = false
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }

    private var configuration: CommandRuntime.Configuration { self.resolvedRuntime.configuration }

    var jsonOutput: Bool { self.configuration.jsonOutput }
    private var isVerbose: Bool { self.configuration.verbose }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        switch self.action.lowercased() {
        case "list":
            try await self.listMenuBarItems()
        case "click":
            try await self.clickMenuBarItem()
        default:
            throw PeekabooError.invalidInput("Unknown action '\(self.action)'. Use 'list' or 'click'.")
        }
    }

    @MainActor
    private func listMenuBarItems() async throws {
        let startTime = Date()

        do {
            self.logger.debug("Listing menu bar items includeRawDebug=\(self.includeRawDebug)")
            let menuBarItems = try await MenuServiceBridge.listMenuBarItems(
                menu: self.services.menu,
                includeRaw: self.includeRawDebug
            )

            if self.jsonOutput {
                let output = ListJSONOutput(
                    success: true,
                    menuBarItems: menuBarItems.map { item in
                        JSONMenuBarItem(
                            title: item.title,
                            raw_title: item.rawTitle,
                            bundle_id: item.bundleIdentifier,
                            owner_name: item.ownerName,
                            identifier: item.identifier,
                            ax_identifier: item.axIdentifier,
                            ax_description: item.axDescription,
                            raw_window_id: item.rawWindowID,
                            raw_window_layer: item.rawWindowLayer,
                            raw_owner_pid: item.rawOwnerPID,
                            raw_source: item.rawSource,
                            index: item.index,
                            isVisible: item.isVisible,
                            description: item.description
                        )
                    },
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                if menuBarItems.isEmpty {
                    print("No menu bar items found.")
                } else {
                    print("📊 Menu Bar Items:")
                    for item in menuBarItems {
                        var info = "  [\(item.index)] \(item.title ?? "Untitled")"
                        if !item.isVisible {
                            info += " (hidden)"
                        }
                        if let desc = item.description, self.isVerbose {
                            info += " - \(desc)"
                        }
                        print(info)
                    }
                    print("\n💡 Tip: Use 'peekaboo menubar click \"name\"' to click a menu bar item")
                }
            }
        } catch {
            if self.jsonOutput {
                let output = JSONErrorOutput(
                    success: false,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                throw error
            }
        }
    }

    @MainActor
    private func clickMenuBarItem() async throws {
        let startTime = Date()

        do {
            let verifyTarget = try await self.resolveVerificationTargetIfNeeded()
            let result: PeekabooCore.ClickResult
            if let idx = self.index {
                result = try await MenuServiceBridge.clickMenuBarItem(at: idx, menu: self.services.menu)
            } else if let name = self.itemName {
                result = try await MenuServiceBridge.clickMenuBarItem(named: name, menu: self.services.menu)
            } else {
                throw PeekabooError.invalidInput("Please provide either a menu bar item name or use --index")
            }

            let verification = try await self.verifyClickIfNeeded(target: verifyTarget)

            if self.jsonOutput {
                let output = ClickJSONOutput(
                    success: true,
                    clicked: result.elementDescription,
                    executionTime: Date().timeIntervalSince(startTime),
                    verified: verification?.verified
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                print("✅ Clicked menu bar item: \(result.elementDescription)")
                if let verification {
                    print("🔎 Verified menu bar click (\(verification.method))")
                }
                if self.isVerbose {
                    print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
                }
            }
        } catch {
            if self.jsonOutput {
                let output = JSONErrorOutput(
                    success: false,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                // Provide helpful hints for common errors
                if error.localizedDescription.contains("not found") {
                    print("❌ Error: \(error.localizedDescription)")
                    print("\n💡 Hints:")
                    print("  • Menu bar items often require clicking on their icon coordinates")
                    print("  • Try 'peekaboo see' first to get element IDs")
                    print("  • Use 'peekaboo menubar list' to see available items")
                } else {
                    throw error
                }
            }
        }
    }

    private func resolveVerificationTargetIfNeeded() async throws -> MenuBarVerifyTarget? {
        guard self.verify else { return nil }

        let items = try await MenuServiceBridge.listMenuBarItems(
            menu: self.services.menu,
            includeRaw: true
        )

        if let idx = self.index {
            guard let item = items.first(where: { $0.index == idx }) else {
                throw PeekabooError.invalidInput("Menu bar item index \(idx) is out of range")
            }
            return MenuBarVerifyTarget(
                title: item.title ?? item.rawTitle,
                ownerPID: item.rawOwnerPID
            )
        }

        guard let name = self.itemName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            throw PeekabooError.invalidInput("Please provide a menu bar item name or use --index")
        }

        guard let item = self.matchMenuBarItem(named: name, items: items) else {
            throw PeekabooError.operationError(message: "Unable to resolve '\(name)' for verification")
        }

        return MenuBarVerifyTarget(
            title: item.title ?? item.rawTitle ?? name,
            ownerPID: item.rawOwnerPID
        )
    }

    private func verifyClickIfNeeded(target: MenuBarVerifyTarget?) async throws -> MenuBarClickVerification? {
        guard self.verify else { return nil }
        guard let target else {
            throw PeekabooError.operationError(message: "Menu bar verification requested but no target resolved")
        }

        let timeout: TimeInterval = 1.5

        if let ownerPID = target.ownerPID {
            if let candidate = await self.waitForPopover(ownerPID: ownerPID, timeout: timeout) {
                return MenuBarClickVerification(verified: true, method: "owner_pid", windowId: candidate.windowId)
            }
        }

        if let expectedTitle = target.title, !expectedTitle.isEmpty {
            if let candidate = try await self.waitForPopoverByOCR(
                expectedTitle: expectedTitle,
                timeout: timeout
            ) {
                return MenuBarClickVerification(verified: true, method: "ocr", windowId: candidate.windowId)
            }
        }

        throw PeekabooError.operationError(message: "Menu bar verification failed: popover not detected")
    }

    private func matchMenuBarItem(named name: String, items: [MenuBarItemInfo]) -> MenuBarItemInfo? {
        let normalized = name.lowercased()
        let candidates: [(MenuBarItemInfo, [String])] = items.map { item in
            let fields = [
                item.title,
                item.rawTitle,
                item.identifier,
                item.axDescription,
                item.ownerName,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            return (item, fields)
        }

        if let exact = candidates.first(where: { _, fields in
            fields.contains(where: { $0.lowercased() == normalized })
        })?.0 {
            return exact
        }

        return candidates.first(where: { _, fields in
            fields.contains(where: { $0.lowercased().contains(normalized) })
        })?.0
    }

    private func waitForPopover(ownerPID: pid_t, timeout: TimeInterval) async -> MenuBarPopoverCandidate? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let candidate = self.findMenuBarPopoverCandidates(ownerPID: ownerPID).first {
                return candidate
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func waitForPopoverByOCR(
        expectedTitle: String,
        timeout: TimeInterval
    ) async throws -> MenuBarPopoverCandidate? {
        let normalized = expectedTitle.lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let candidates = self.findMenuBarPopoverCandidates(ownerPID: nil)
            for candidate in candidates {
                guard let result = try? await self.captureWindow(windowId: candidate.windowId) else { continue }
                guard let ocr = try? OCRService.recognizeText(in: result.imageData) else { continue }
                let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
                if text.contains(normalized) {
                    return candidate
                }
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return nil
    }

    private func findMenuBarPopoverCandidates(ownerPID: pid_t?) -> [MenuBarPopoverCandidate] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var candidates: [MenuBarPopoverCandidate] = []

        for windowInfo in windowList {
            guard let bounds = self.windowBounds(from: windowInfo) else { continue }
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }

            let ownerPIDValue = windowInfo[kCGWindowOwnerPID as String] as? pid_t ?? -1
            if let ownerPID, ownerPIDValue != ownerPID { continue }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
            let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
            if !isOnScreen || alpha < 0.05 { continue }

            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let title = windowInfo[kCGWindowName as String] as? String ?? ""
            if ownerName == "Window Server", title == "Menubar" { continue }

            if bounds.width < 40 || bounds.height < 40 { continue }

            let screen = self.screenContainingWindow(bounds: bounds) ??
                NSScreen.main ??
                NSScreen.screens.first
            let menuBarHeight = self.menuBarHeight(for: screen)
            if (layer == 24 || layer == 25), bounds.height <= menuBarHeight + 4 { continue }

            if let screen {
                let maxHeight = screen.frame.height * 0.8
                if bounds.height > maxHeight { continue }

                let menuBarY = screen.visibleFrame.maxY
                if bounds.maxY < menuBarY - 8 { continue }
            }

            candidates.append(
                MenuBarPopoverCandidate(
                    windowId: windowId,
                    ownerPID: ownerPIDValue,
                    bounds: bounds
                )
            )
        }

        return candidates
    }

    private func captureWindow(windowId: Int) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await self.services.screenCapture.captureWindow(windowID: CGWindowID(windowId))
        }.value
    }

    private func windowBounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func menuBarHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else { return 24.0 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    private func screenContainingWindow(bounds: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        var bestScreen: NSScreen?
        var maxOverlap: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(bounds)
            let overlapArea = intersection.width * intersection.height
            if overlapArea > maxOverlap {
                maxOverlap = overlapArea
                bestScreen = screen
            }
        }

        return bestScreen
    }
}

// MARK: - JSON Output Types

private struct JSONMenuBarItem: Codable {
    let title: String?
    let raw_title: String?
    let bundle_id: String?
    let owner_name: String?
    let identifier: String?
    let ax_identifier: String?
    let ax_description: String?
    let raw_window_id: CGWindowID?
    let raw_window_layer: Int?
    let raw_owner_pid: pid_t?
    let raw_source: String?
    let index: Int
    let isVisible: Bool
    let description: String?
}

private struct ListJSONOutput: Codable {
    let success: Bool
    let menuBarItems: [JSONMenuBarItem]
    let executionTime: TimeInterval
}

private struct ClickJSONOutput: Codable {
    let success: Bool
    let clicked: String
    let executionTime: TimeInterval
    let verified: Bool?
}

private struct MenuBarVerifyTarget {
    let title: String?
    let ownerPID: pid_t?
}

private struct MenuBarClickVerification {
    let verified: Bool
    let method: String
    let windowId: Int?
}

private struct MenuBarPopoverCandidate {
    let windowId: Int
    let ownerPID: pid_t
    let bounds: CGRect
}

private struct JSONErrorOutput: Codable {
    let success: Bool
    let error: String
    let executionTime: TimeInterval
}

extension MenuBarCommand: AsyncRuntimeCommand {}

@MainActor
extension MenuBarCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.action = try values.decodePositional(0, label: "action")
        self.itemName = try values.decodeOptionalPositional(1, label: "itemName")
        self.index = try values.decodeOption("index", as: Int.self)
        self.includeRawDebug = values.flag("includeRawDebug")
        self.verify = values.flag("verify")
    }
}
