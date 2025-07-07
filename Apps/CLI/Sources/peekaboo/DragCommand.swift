import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation

struct DragCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "drag",
        abstract: "Perform drag and drop operations",
        discussion: """
        Execute click-and-drag operations for moving elements, selecting text, or dragging files.

        EXAMPLES:
          # Drag between UI elements
          peekaboo drag --from B1 --to T2

          # Drag with coordinates
          peekaboo drag --from-coords "100,200" --to-coords "400,300"

          # Drag to an application
          peekaboo drag --from B1 --to-app Trash

          # Slow drag for precise operations
          peekaboo drag --from S1 --to-coords "500,250" --duration 2000

          # Multi-select with modifier keys
          peekaboo drag --from T1 --to T5 --modifiers shift
        """,
        version: "3.0.0")

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

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        // Validate inputs
        guard self.from != nil || self.fromCoords != nil else {
            throw ValidationError("Must specify either --from or --from-coords")
        }

        guard self.to != nil || self.toCoords != nil || self.toApp != nil else {
            throw ValidationError("Must specify either --to, --to-coords, or --to-app")
        }

        do {
            // Resolve starting point
            let startPoint = try await resolvePoint(
                elementId: from,
                coords: fromCoords,
                session: session,
                description: "from")

            // Resolve ending point
            let endPoint: CGPoint = if let targetApp = toApp {
                // Find application window or dock item
                try await findApplicationPoint(targetApp)
            } else {
                try await resolvePoint(
                    elementId: self.to,
                    coords: self.toCoords,
                    session: self.session,
                    description: "to")
            }

            // Parse modifiers
            let eventFlags = parseModifiers(modifiers)

            // Perform the drag
            performDrag(
                from: startPoint,
                to: endPoint,
                duration: self.duration,
                steps: self.steps,
                flags: eventFlags)

            // Output result
            if self.jsonOutput {
                let response = JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "action": "drag",
                        "from": ["x": Int(startPoint.x), "y": Int(startPoint.y)],
                        "to": ["x": Int(endPoint.x), "y": Int(endPoint.y)],
                        "duration_ms": self.duration,
                        "steps": self.steps,
                        "modifiers": self.modifiers ?? "none",
                    ]))
                outputJSON(response)
            } else {
                print(
                    "✓ Dragged from (\(Int(startPoint.x)), \(Int(startPoint.y))) to (\(Int(endPoint.x)), \(Int(endPoint.y)))")
                if let mods = modifiers {
                    print("  Modifiers: \(mods)")
                }
            }

        } catch let error as DragError {
            handleDragError(error, jsonOutput: jsonOutput)
        } catch let error as ValidationError {
            if jsonOutput {
                let response = JSONResponse(
                    success: false,
                    error: ErrorInfo(
                        message: error.localizedDescription,
                        code: .VALIDATION_ERROR))
                outputJSON(response)
            } else {
                print("❌ \(error.localizedDescription)")
            }
        } catch {
            if self.jsonOutput {
                let response = JSONResponse(
                    success: false,
                    error: ErrorInfo(
                        message: error.localizedDescription,
                        code: .UNKNOWN_ERROR))
                outputJSON(response)
            } else {
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Helper Functions

private func resolvePoint(
    elementId: String?,
    coords: String?,
    session: String?,
    description: String) async throws -> CGPoint
{
    if let coordString = coords {
        // Parse coordinates
        let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1])
        else {
            throw DragError.invalidCoordinates(coordString)
        }
        return CGPoint(x: x, y: y)
    } else if let element = elementId {
        // Resolve from session
        let sessionId = try await resolveSessionId(session)
        let sessionCache = try SessionCache(sessionId: sessionId)

        guard let sessionData = await sessionCache.load() else {
            throw DragError.sessionNotFound(sessionId)
        }

        guard let uiElement = sessionData.uiMap[element] else {
            throw DragError.elementNotFound(element)
        }

        // Return center of element
        let frame = uiElement.frame
        return CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2)
    } else {
        throw DragError.noPointSpecified(description)
    }
}

@MainActor
private func findApplicationPoint(_ appName: String) async throws -> CGPoint {
    // Special handling for Trash
    if appName.lowercased() == "trash" {
        // Find Dock and locate Trash
        if let dock = findDockApplication() {
            if let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) {
                let items = dockList.children() ?? []

                // Trash is typically the last item
                if let trash = items.last {
                    if let position = trash.position(),
                       let size = trash.size()
                    {
                        return CGPoint(
                            x: position.x + size.width / 2,
                            y: position.y + size.height / 2)
                    }
                }
            }
        }
        throw DragError.applicationNotFound("Trash")
    }

    // Try to find application window
    do {
        let (app, _) = try await findApplication(identifier: appName)

        // Get main window
        if let window = app.mainWindow() ?? app.focusedWindow() {
            if let position = window.position(),
               let size = window.size()
            {
                // Return center of window
                return CGPoint(
                    x: position.x + size.width / 2,
                    y: position.y + size.height / 2)
            }
        }

        throw DragError.windowNotFound(appName)
    } catch {
        // If not found as running app, try dock
        if let dock = findDockApplication() {
            if let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) {
                let items = dockList.children() ?? []

                if let appItem = items.first(where: { item in
                    item.title() == appName ||
                        item.title()?.contains(appName) == true
                }) {
                    if let position = appItem.position(),
                       let size = appItem.size()
                    {
                        return CGPoint(
                            x: position.x + size.width / 2,
                            y: position.y + size.height / 2)
                    }
                }
            }
        }

        throw DragError.applicationNotFound(appName)
    }
}

private func parseModifiers(_ modifierString: String?) -> CGEventFlags {
    guard let modString = modifierString else { return [] }

    var flags: CGEventFlags = []
    let modifiers = modString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

    for modifier in modifiers {
        switch modifier {
        case "cmd", "command":
            flags.insert(.maskCommand)
        case "shift":
            flags.insert(.maskShift)
        case "option", "opt", "alt":
            flags.insert(.maskAlternate)
        case "ctrl", "control":
            flags.insert(.maskControl)
        default:
            break
        }
    }

    return flags
}

private func performDrag(
    from startPoint: CGPoint,
    to endPoint: CGPoint,
    duration: Int,
    steps: Int,
    flags: CGEventFlags)
{
    // Calculate step increments
    let deltaX = endPoint.x - startPoint.x
    let deltaY = endPoint.y - startPoint.y
    let stepDuration = duration / steps
    let stepDelay = UInt32(stepDuration * 1000) // Convert to microseconds

    // Mouse down at start point
    let mouseDown = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseDown,
        mouseCursorPosition: startPoint,
        mouseButton: .left)
    mouseDown?.flags = flags
    mouseDown?.post(tap: .cghidEventTap)

    // Drag through intermediate points
    for i in 1...steps {
        let progress = Double(i) / Double(steps)
        let currentX = startPoint.x + (deltaX * progress)
        let currentY = startPoint.y + (deltaY * progress)
        let currentPoint = CGPoint(x: currentX, y: currentY)

        let dragEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDragged,
            mouseCursorPosition: currentPoint,
            mouseButton: .left)
        dragEvent?.flags = flags
        dragEvent?.post(tap: .cghidEventTap)

        usleep(stepDelay)
    }

    // Mouse up at end point
    let mouseUp = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseUp,
        mouseCursorPosition: endPoint,
        mouseButton: .left)
    mouseUp?.flags = flags
    mouseUp?.post(tap: .cghidEventTap)
}

@MainActor
private func findDockApplication() -> Element? {
    let workspace = NSWorkspace.shared
    guard let dockApp = workspace.runningApplications.first(where: {
        $0.bundleIdentifier == "com.apple.dock"
    }) else {
        return nil
    }

    return Element(AXUIElementCreateApplication(dockApp.processIdentifier))
}

// MARK: - Drag Errors

enum DragError: LocalizedError {
    case invalidCoordinates(String)
    case elementNotFound(String)
    case sessionNotFound(String)
    case applicationNotFound(String)
    case windowNotFound(String)
    case noPointSpecified(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCoordinates(coords):
            "Invalid coordinates format: '\(coords)'. Expected 'x,y'"
        case let .elementNotFound(element):
            "Element '\(element)' not found in session"
        case let .sessionNotFound(session):
            "Session '\(session)' not found"
        case let .applicationNotFound(app):
            "Application '\(app)' not found"
        case let .windowNotFound(app):
            "No window found for application '\(app)'"
        case let .noPointSpecified(description):
            "No \(description) point specified"
        }
    }

    var errorCode: String {
        switch self {
        case .invalidCoordinates:
            "INVALID_COORDINATES"
        case .elementNotFound:
            "ELEMENT_NOT_FOUND"
        case .sessionNotFound:
            "SESSION_NOT_FOUND"
        case .applicationNotFound:
            "APPLICATION_NOT_FOUND"
        case .windowNotFound:
            "WINDOW_NOT_FOUND"
        case .noPointSpecified:
            "NO_POINT_SPECIFIED"
        }
    }
}

// MARK: - Error Handling

private func handleDragError(_ error: DragError, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

// MARK: - Session Errors

enum SessionError: LocalizedError {
    case noSessionsFound
    case noValidSessionFound
    case sessionAccessError(String)

    var errorDescription: String? {
        switch self {
        case .noSessionsFound:
            "No sessions found"
        case .noValidSessionFound:
            "No valid session found within the last 10 minutes"
        case let .sessionAccessError(error):
            "Failed to access session: \(error)"
        }
    }
}

// MARK: - Session Resolution

private func resolveSessionId(_ explicitId: String?) async throws -> String {
    if let sessionId = explicitId {
        return sessionId
    }

    // Find most recent session
    let sessionDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".peekaboo/session")

    guard FileManager.default.fileExists(atPath: sessionDir.path) else {
        throw SessionError.noSessionsFound
    }

    let tenMinutesAgo = Date().addingTimeInterval(-600)

    do {
        let contents = try FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles])

        let validSessions = try contents.compactMap { url -> (String, Date)? in
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
            guard let creationDate = resourceValues.creationDate,
                  creationDate > tenMinutesAgo
            else {
                return nil
            }
            return (url.lastPathComponent, creationDate)
        }

        guard let latestSession = validSessions.sorted(by: { $0.1 > $1.1 }).first else {
            throw SessionError.noValidSessionFound
        }

        return latestSession.0
    } catch {
        throw SessionError.sessionAccessError(error.localizedDescription)
    }
}
