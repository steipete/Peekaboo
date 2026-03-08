import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Click on UI elements identified in the current snapshot using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
@MainActor
struct ClickCommand: ErrorHandlingCommand, OutputFormattable {
    @Argument(help: "Element text or query to click")
    var query: String?

    @Option(help: "Snapshot ID (uses latest if not specified)")
    var snapshot: String?

    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?

    @Option(name: .customLong("id"), help: "Element ID to click (alias for --on)")
    var id: String?

    @OptionGroup var target: InteractionTargetOptions

    @Option(help: "Click at coordinates (x,y)")
    var coords: String?

    @Option(help: "Maximum milliseconds to wait for element")
    var waitFor: Int = 5000

    @Flag(help: "Double-click instead of single click")
    var double = false

    @Flag(help: "Right-click (secondary click)")
    var right = false

    @OptionGroup var focusOptions: FocusCommandOptions
    mutating func validate() throws {
        try self.target.validate()
        guard self.query != nil || self.on != nil || self.id != nil || self.coords != nil else {
            throw ValidationError("Specify an element query, --on/--id, or --coords.")
        }

        if self.on != nil && self.coords != nil {
            throw ValidationError("Cannot specify both --on and --coords.")
        }

        if self.on != nil && self.id != nil {
            throw ValidationError("Cannot specify both --on and --id.")
        }

        if let coordString = coords {
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  Double(parts[0]) != nil,
                  Double(parts[1]) != nil else {
                throw ValidationError("Invalid coordinates format. Use: x,y")
            }
        }
    }

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding {
        self.resolvedRuntime.services
    }

    private var logger: Logger {
        self.resolvedRuntime.logger
    }

    var outputLogger: Logger {
        self.logger
    }

    var jsonOutput: Bool {
        self.resolvedRuntime.configuration.jsonOutput
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        let startTime = Date()

        do {
            try self.validate()

            // Determine click target first to check if we need a snapshot
            let clickTarget: ClickTarget
            let waitResult: WaitForElementResult
            let activeSnapshotId: String

            // Check if we're clicking by coordinates (doesn't need snapshot)
            if let coordString = coords {
                // Click by coordinates (no snapshot needed)
                guard let point = Self.parseCoordinates(coordString) else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(point)
                waitResult = WaitForElementResult(found: true, element: nil, waitTime: 0)
                activeSnapshotId = "" // Not needed for coordinate clicks
                try await self.focusApplicationIfNeeded(snapshotId: nil)

                // Verify target app is actually frontmost after focus attempt.
                // InputDriver.click() sends a CGEvent at screen-absolute coordinates,
                // so if the target window is not frontmost, the click will land on
                // whatever window is at that position (see #90).
                try self.verifyFocusForCoordinateClick()

            } else {
                // For element-based clicks, try to get a snapshot but allow fallback
                let explicitSnapshotId = self.snapshot?.trimmingCharacters(in: .whitespacesAndNewlines)
                let providedSnapshotId = explicitSnapshotId?.isEmpty == false ? explicitSnapshotId : nil
                let snapshotIdForAutomation: String? = if let providedSnapshotId {
                    providedSnapshotId
                } else {
                    await self.services.snapshots.getMostRecentSnapshot()
                }

                // Use snapshot if available, otherwise use empty string to indicate no snapshot.
                activeSnapshotId = snapshotIdForAutomation ?? ""

                // If the user explicitly passed --snapshot, fail early if that snapshot doesn't exist anymore.
                if let providedSnapshot = providedSnapshotId {
                    _ = try await SnapshotValidation.requireDetectionResult(
                        snapshotId: providedSnapshot,
                        snapshots: self.services.snapshots
                    )
                }

                let focusSnapshotId: String? = if providedSnapshotId != nil || !self.target.hasAnyTarget {
                    activeSnapshotId.isEmpty ? nil : activeSnapshotId
                } else {
                    nil
                }

                try await self.focusApplicationIfNeeded(snapshotId: focusSnapshotId)

                // Use whichever element ID parameter was provided
                let elementId = self.on ?? self.id

                if let elementId {
                    // Click by element ID with auto-wait
                    clickTarget = .elementId(elementId)
                    waitResult = try await AutomationServiceBridge.waitForElement(
                        automation: self.services.automation,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId
                    )

                    if !waitResult.found {
                        var message = "Element with ID '\(elementId)' not found"
                        message += "\n\n💡 Hints:"
                        message += "\n  • Run 'peekaboo see' first to capture UI elements"
                        message += "\n  • Check that the element ID is correct (e.g., B1, T2)"
                        message += "\n  • Element may have disappeared or changed"
                        throw PeekabooError.elementNotFound(message)
                    }

                } else if let searchQuery = query {
                    // Find element by query with auto-wait
                    clickTarget = .query(searchQuery)
                    waitResult = try await AutomationServiceBridge.waitForElement(
                        automation: self.services.automation,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId
                    )

                    if !waitResult.found {
                        var message = "No actionable element found matching '\(searchQuery)' after \(self.waitFor)ms"
                        message += "\n\n💡 Hints:"
                        message += "\n  • Menu bar items often require clicking on their icon coordinates"
                        message += "\n  • Try 'peekaboo see' first to get element IDs"
                        message += "\n  • Use partial text matching (case-insensitive)"
                        message += "\n  • Element might be disabled or not visible"
                        message += "\n  • Try increasing --wait-for timeout"
                        throw PeekabooError.elementNotFound(message)
                    }

                } else {
                    // This case should not be reachable due to the validate() method
                    throw ValidationError("No target specified for click.")
                }
            }

            // Determine click type
            let clickType: ClickType = self.right ? .right : (self.double ? .double : .single)

            // Perform the click
            if case .coordinates = clickTarget {
                // For coordinate clicks, pass nil snapshot ID
                try await AutomationServiceBridge.click(
                    automation: self.services.automation,
                    target: clickTarget,
                    clickType: clickType,
                    snapshotId: nil
                )
            } else {
                // For element-based clicks, pass the snapshot ID
                try await AutomationServiceBridge.click(
                    automation: self.services.automation,
                    target: clickTarget,
                    clickType: clickType,
                    snapshotId: activeSnapshotId.isEmpty ? nil : activeSnapshotId
                )
            }

            // Brief delay to ensure click is processed
            try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds

            // Get the frontmost app after clicking
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let appName = frontmostApp?.localizedName ?? "Unknown"

            // Prepare result
            let clickLocation: CGPoint
            let clickedElement: String?

            switch clickTarget {
            case let .elementId(id):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Shouldn't happen but handle gracefully
                    clickLocation = .zero
                    clickedElement = "Element ID: \(id)"
                }

            case let .coordinates(point):
                clickLocation = point
                clickedElement = nil

            case let .query(query):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Use a default description
                    clickLocation = .zero
                    clickedElement = "Element matching: \(query)"
                }
            }

            // Output results
            let result = ClickResult(
                success: true,
                clickedElement: clickedElement,
                clickLocation: clickLocation,
                waitTime: waitResult.waitTime,
                executionTime: Date().timeIntervalSince(startTime),
                targetApp: appName
            )

            output(result) {
                print("✅ Click successful")
                print("🎯 App: \(appName)")
                if let info = clickedElement {
                    print("📱 Clicked: \(info)")
                }
                print("📍 Location: (\(Int(clickLocation.x)), \(Int(clickLocation.y)))")
                if waitResult.waitTime > 0 {
                    print("⏳ Waited: \(String(format: "%.1f", waitResult.waitTime))s")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
    }

    private func focusApplicationIfNeeded(snapshotId: String?) async throws {
        guard self.focusOptions.autoFocus else {
            return
        }

        if snapshotId == nil, !self.target.hasAnyTarget {
            return
        }

        try await ensureFocused(
            snapshotId: snapshotId,
            target: self.target,
            options: self.focusOptions,
            services: self.services
        )

        // Brief delay to ensure focus is complete before interacting
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Verify that the target app is actually frontmost before dispatching a coordinate click.
    ///
    /// When `--app` is specified with `--coords`, the click uses `InputDriver.click()` which
    /// sends a CGEvent at screen-absolute coordinates. If the focus step didn't actually bring
    /// the target window to the front (common with Electron apps like Claude Desktop, VS Code),
    /// the click will land on whatever window happens to be at that screen position.
    ///
    /// This method checks that the frontmost app matches the `--app` target and logs a warning
    /// if it doesn't, giving the agent actionable feedback instead of silently clicking the wrong app.
    private func verifyFocusForCoordinateClick() throws {
        // Only verify when --app is explicitly specified
        guard let targetApp = self.target.app else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostName = frontmost?.localizedName ?? ""
        let frontmostBundle = frontmost?.bundleIdentifier ?? ""

        let nameMatches = frontmostName.localizedCaseInsensitiveContains(targetApp)
        let bundleMatches = frontmostBundle.localizedCaseInsensitiveContains(targetApp)

        if !nameMatches && !bundleMatches {
            self.logger.warning(
                "Focus mismatch: target app '\(targetApp)' is not frontmost. " +
                "Frontmost is '\(frontmostName)' (\(frontmostBundle)). " +
                "Coordinate click may land on the wrong window."
            )
            // Throw so the agent gets clear feedback instead of silently clicking wrong app
            throw PeekabooError.elementNotFound(
                "Target app '\(targetApp)' is not frontmost after focus attempt. " +
                "Currently frontmost: '\(frontmostName)'. " +
                "The coordinate click would land on '\(frontmostName)' instead.\n\n" +
                "💡 Hints:\n" +
                "  • Ensure no other window is overlapping the target\n" +
                "  • Try clicking by element ID (--on) instead of coordinates\n" +
                "  • Close or minimize interfering windows first"
            )
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

@MainActor
extension ClickCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.query = try values.decodeOptionalPositional(0, label: "query")
        self.snapshot = values.singleOption("snapshot")
        self.on = values.singleOption("on")
        self.id = values.singleOption("id")
        self.target = try values.makeInteractionTargetOptions()
        self.coords = values.singleOption("coords")
        if let wait: Int = try values.decodeOption("waitFor", as: Int.self) {
            self.waitFor = wait
        }
        self.double = values.flag("double")
        self.right = values.flag("right")
        self.focusOptions = try values.makeFocusOptions()
    }
}

// MARK: - JSON Output Structure

struct ClickResult: Codable {
    let success: Bool
    let clickedElement: String?
    let clickLocation: [String: Double]
    let waitTime: Double
    let executionTime: TimeInterval
    let targetApp: String

    init(
        success: Bool,
        clickedElement: String?,
        clickLocation: CGPoint,
        waitTime: Double,
        executionTime: TimeInterval,
        targetApp: String
    ) {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
        self.targetApp = targetApp
    }
}

// MARK: - Static Helper Methods for Testing

extension ClickCommand {
    /// Parse coordinates string (e.g., "100,200") into CGPoint
    static func parseCoordinates(_ coords: String) -> CGPoint? {
        // Parse coordinates string (e.g., "100,200") into CGPoint
        let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    /// Create element locator from query string
    static func createLocatorFromQuery(_ query: String) -> (type: String, value: String) {
        // Simple heuristic for determining locator type
        if query.hasPrefix("#") {
            ("id", String(query.dropFirst()))
        } else if query.hasPrefix(".") {
            ("class", String(query.dropFirst()))
        } else if query.hasPrefix("//") || query.hasPrefix("/") {
            ("xpath", query)
        } else {
            ("text", query)
        }
    }
}

@MainActor
extension ClickCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        let definition = UIAutomationToolDefinitions.click.commandConfiguration
        return CommandDescription(
            commandName: definition.commandName,
            abstract: definition.abstract,
            discussion: definition.discussion,
            showHelpOnEmptyInvocation: true
        )
    }
}

extension ClickCommand: AsyncRuntimeCommand {}
