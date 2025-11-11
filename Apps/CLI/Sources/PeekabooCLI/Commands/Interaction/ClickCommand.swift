import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Click on UI elements identified in the current session using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
@MainActor
struct ClickCommand: ErrorHandlingCommand, OutputFormattable {
    @Argument(help: "Element text or query to click")
    var query: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?

    @Option(name: .customLong("id"), help: "Element ID to click (alias for --on)")
    var id: String?

    @Option(help: "Application name to focus before clicking")
    var app: String?

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
                  let _ = Double(parts[0]),
                  let _ = Double(parts[1])
            else {
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

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
        let startTime = Date()

        do {
            // Determine click target first to check if we need a session
            let clickTarget: ClickTarget
            let waitResult: WaitForElementResult
            let activeSessionId: String

            // Check if we're clicking by coordinates (doesn't need session)
            if let coordString = coords {
                // Click by coordinates (no session needed)
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let x = Double(parts[0])!
                let y = Double(parts[1])!
                clickTarget = .coordinates(CGPoint(x: x, y: y))
                waitResult = WaitForElementResult(found: true, element: nil, waitTime: 0)
                activeSessionId = "" // Not needed for coordinate clicks

            } else {
                // For element-based clicks, try to get a session but allow fallback
                let sessionId: String? = if let providedSession = session {
                    providedSession
                } else {
                    await self.services.sessions.getMostRecentSession()
                }
                // Use session if available, otherwise use empty string to indicate no session
                activeSessionId = sessionId ?? ""

                // If app is specified, focus it first
                if let appName = app {
                    // Focus the specified app
                    try await WindowServiceBridge.focusWindow(services: self.services, target: .application(appName))
                    // Brief delay to ensure focus is complete
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }

                // Ensure window is focused before clicking (if auto-focus is enabled)
                try await ensureFocused(
                    sessionId: activeSessionId,
                    applicationName: self.app,
                    options: self.focusOptions,
                    services: self.services
                )

                // Use whichever element ID parameter was provided
                let elementId = self.on ?? self.id

                if let elementId {
                    // Click by element ID with auto-wait
                    clickTarget = .elementId(elementId)
                    waitResult = try await AutomationServiceBridge.waitForElement(
                        services: self.services,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId.isEmpty ? nil : activeSessionId
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
                        services: self.services,
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId.isEmpty ? nil : activeSessionId
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
                // For coordinate clicks, pass nil session ID
                try await AutomationServiceBridge.click(
                    services: self.services,
                    target: clickTarget,
                    clickType: clickType,
                    sessionId: nil
                )
            } else {
                // For element-based clicks, pass the session ID
                try await AutomationServiceBridge.click(
                    services: self.services,
                    target: clickTarget,
                    clickType: clickType,
                    sessionId: activeSessionId.isEmpty ? nil : activeSessionId
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

    // Error handling is provided by ErrorHandlingCommand protocol
}

@MainActor
extension ClickCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.query = try values.decodeOptionalPositional(0, label: "query")
        self.session = values.singleOption("session")
        self.on = values.singleOption("on")
        self.id = values.singleOption("id")
        self.app = values.singleOption("app")
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
            discussion: definition.discussion
        )
    }
}

extension ClickCommand: AsyncRuntimeCommand {}
