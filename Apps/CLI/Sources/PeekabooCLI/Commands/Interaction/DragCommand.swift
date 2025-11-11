import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Perform drag and drop operations using intelligent element finding
@available(macOS 14.0, *)
@MainActor
struct DragCommand: ErrorHandlingCommand, OutputFormattable {
    @Option(help: "Starting element ID from session")
    var from: String?

    @Option(help: "Starting coordinates as 'x,y'")
    var fromCoords: String?

    @Option(help: "Target element ID from session")
    var to: String?

    @Option(help: "Target coordinates as 'x,y'")
    var toCoords: String?

    @Option(help: "Target application (e.g., 'Trash', 'Finder')")
    var toApp: String?

    @Option(help: "Session ID for element resolution")
    var session: String?

    @Option(help: "Duration of drag in milliseconds (default: 500)")
    var duration: Int = 500

    @Option(help: "Number of intermediate steps (default: 20)")
    var steps: Int = 20

    @Option(help: "Modifier keys to hold during drag (comma-separated: cmd,shift,option,ctrl)")
    var modifiers: String?
    @OptionGroup var focusOptions: FocusCommandOptions
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
            try self.validateInputs()

            let sessionId = try await self.resolveSession()
            if let sessionId {
                try await ensureFocused(
                    sessionId: sessionId,
                    options: self.focusOptions,
                    services: self.services
                )
            }

            let startPoint = try await self.resolvePoint(
                elementId: self.from,
                coords: self.fromCoords,
                sessionId: sessionId,
                description: "from"
            )

            let endPoint: CGPoint = if let targetApp = toApp {
                try await self.findApplicationPoint(targetApp)
            } else {
                try await self.resolvePoint(
                    elementId: self.to,
                    coords: self.toCoords,
                    sessionId: sessionId,
                    description: "to"
                )
            }

            try await AutomationServiceBridge.drag(
                services: self.services,
                from: startPoint,
                to: endPoint,
                duration: self.duration,
                steps: self.steps,
                modifiers: self.modifiers
            )

            try await Task.sleep(nanoseconds: 100_000_000)

            let result = DragResult(
                success: true,
                from: ["x": Int(startPoint.x), "y": Int(startPoint.y)],
                to: ["x": Int(endPoint.x), "y": Int(endPoint.y)],
                duration: self.duration,
                steps: self.steps,
                modifiers: self.modifiers ?? "none",
                executionTime: Date().timeIntervalSince(startTime)
            )

            output(result) {
                print("✅ Drag successful")
                print("📍 From: (\(Int(startPoint.x)), \(Int(startPoint.y)))")
                print("📍 To: (\(Int(endPoint.x)), \(Int(endPoint.y)))")
                print("⏱️  Duration: \(self.duration)ms with \(self.steps) steps")
                if let mods = modifiers {
                    print("⌨️  Modifiers: \(mods)")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }
        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    // Validate user input combinations
    private func validateInputs() throws {
        guard self.from != nil || self.fromCoords != nil else {
            throw ValidationError("Must specify either --from or --from-coords")
        }

        guard self.to != nil || self.toCoords != nil || self.toApp != nil else {
            throw ValidationError("Must specify either --to, --to-coords, or --to-app")
        }

        if self.to != nil || self.toCoords != nil {
            guard (self.to != nil) != (self.toCoords != nil) else {
                throw ValidationError("Specify only one of --to or --to-coords")
            }
        }

        if self.from != nil && self.fromCoords != nil {
            throw ValidationError("Specify only one of --from or --from-coords")
        }
    }

    private func resolveSession() async throws -> String? {
        if let provided = self.session {
            return provided
        }
        return await self.services.sessions.getMostRecentSession()
    }

    private func resolvePoint(
        elementId: String?,
        coords: String?,
        sessionId: String?,
        description: String
    ) async throws -> CGPoint {
        if let coordinateString = coords {
            let components = coordinateString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 2,
                  let x = Double(components[0]),
                  let y = Double(components[1])
            else {
                throw ValidationError("Invalid coordinates format: '\(coordinateString)'. Expected 'x,y'")
            }
            return CGPoint(x: x, y: y)
        }

        guard let element = elementId else {
            throw ValidationError("No \(description) point specified")
        }

        guard let sessionId else {
            throw ValidationError("Session ID required when using element IDs")
        }

        let target = ClickTarget.elementId(element)
        let waitResult = try await AutomationServiceBridge.waitForElement(
            services: self.services,
            target: target,
            timeout: 5.0,
            sessionId: sessionId
        )

        guard waitResult.found, let foundElement = waitResult.element else {
            throw PeekabooError.elementNotFound("Element with ID '\(element)' not found")
        }

        return CGPoint(
            x: foundElement.bounds.origin.x + foundElement.bounds.width / 2,
            y: foundElement.bounds.origin.y + foundElement.bounds.height / 2
        )
    }

    private func findApplicationPoint(_ appName: String) async throws -> CGPoint {
        if appName.lowercased() == "trash" {
            return try await self.findTrashPoint()
        }

        return try await Task { @MainActor
            in
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: appName).first else {
                throw PeekabooError.appNotFound(appName)
            }

            let appElement = Element(AXUIElementCreateApplication(app.processIdentifier))
            guard let windowElement = appElement.focusedWindow() else {
                throw PeekabooError.windowNotFound(criteria: "No focused window for \(app.localizedName ?? appName)")
            }

            guard let frame = windowElement.frame() else {
                throw PeekabooError
                    .windowNotFound(criteria: "Window bounds unavailable for \(app.localizedName ?? appName)")
            }

            return CGPoint(x: frame.midX, y: frame.midY)
        }.value
    }

    private func findTrashPoint() async throws -> CGPoint {
        guard let dock = await self.findDockApplication(),
              let list = dock.children()?.first(where: { $0.role() == "AXList" })
        else {
            throw PeekabooError.elementNotFound("Dock not found")
        }

        let items = list.children() ?? []
        if let trash = items.first(where: { $0.label()?.lowercased() == "trash" }) {
            if let position = trash.position(), let size = trash.size() {
                return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
            }
        }

        throw PeekabooError.elementNotFound("Trash not found in Dock")
    }

    private func findDockApplication() async -> Element? {
        await MainActor.run {
            let apps = NSWorkspace.shared.runningApplications
            guard let dockApp = apps.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
                return nil
            }
            return Element(AXUIElementCreateApplication(dockApp.processIdentifier))
        }
    }
}

// MARK: - Output Types

private struct DragResult: Codable {
    let success: Bool
    let from: [String: Int]
    let to: [String: Int]
    let duration: Int
    let steps: Int
    let modifiers: String
    let executionTime: TimeInterval
}

// MARK: - Conformances

@MainActor
extension DragCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "drag",
                abstract: "Perform drag and drop operations",
                discussion: """
                Execute click-and-drag operations for moving elements, selecting text, or dragging files.

                EXAMPLES:
                  peekaboo drag --from B1 --to T2
                  peekaboo drag --from-coords "100,200" --to-coords "400,300"
                  peekaboo drag --from B1 --to-app Trash
                  peekaboo drag --from S1 --to-coords "500,250" --duration 2000
                  peekaboo drag --from T1 --to T5 --modifiers shift
                """,
                version: "2.0.0"
            )
        }
    }
}

extension DragCommand: AsyncRuntimeCommand {}

@MainActor
extension DragCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.from = values.singleOption("from")
        self.fromCoords = values.singleOption("fromCoords")
        self.to = values.singleOption("to")
        self.toCoords = values.singleOption("toCoords")
        self.toApp = values.singleOption("toApp")
        self.session = values.singleOption("session")
        if let duration: Int = try values.decodeOption("duration", as: Int.self) {
            self.duration = duration
        }
        if let steps: Int = try values.decodeOption("steps", as: Int.self) {
            self.steps = steps
        }
        self.modifiers = values.singleOption("modifiers")
        self.focusOptions = try values.makeFocusOptions()
    }
}
