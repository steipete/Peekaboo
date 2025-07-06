// Example of how DragCommand would be refactored with new AXorcist APIs

import ArgumentParser
import Foundation
import ApplicationServices
import AXorcist

struct DragCommandRefactored: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "drag",
        abstract: "Perform drag and drop operations"
    )
    
    @Option var from: String?
    @Option var to: String?
    @Option(name: .customLong("from-coords")) var fromCoords: String?
    @Option(name: .customLong("to-coords")) var toCoords: String?
    @Option(name: .customLong("to-app")) var toApp: String?
    @Option var duration: Int = 500
    @Option var modifiers: String?
    @Option var session: String?
    @Flag(name: .customLong("json-output")) var jsonOutput = false
    
    @MainActor
    mutating func run() async throws {
        do {
            // Get start and end points
            let startPoint = try await resolvePoint(from: from, coords: fromCoords, session: session)
            let endPoint = try await resolvePoint(to: to, coords: toCoords, toApp: toApp, session: session)
            
            // Parse modifiers
            let modifierKeys = parseModifiersRefactored(modifiers)
            let eventFlags = CGEventFlags.from(modifiers: modifierKeys)
            
            // NEW: Use EventSynthesizer instead of manual CGEvent creation
            EventSynthesizer.drag(
                from: startPoint,
                to: endPoint,
                duration: Double(duration) / 1000.0,
                modifiers: eventFlags
            )
            
            // Output result
            if jsonOutput {
                let response = JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "action": "drag",
                        "from": "(\(startPoint.x), \(startPoint.y))",
                        "to": "(\(endPoint.x), \(endPoint.y))",
                        "duration": duration,
                        "modifiers": modifiers ?? "none"
                    ])
                )
                outputJSON(response)
            } else {
                print("✓ Dragged from (\(Int(startPoint.x)), \(Int(startPoint.y))) to (\(Int(endPoint.x)), \(Int(endPoint.y)))")
            }
            
        } catch let error as DragError {
            handleDragError(error, jsonOutput: jsonOutput)
        } catch {
            handleGenericError(error, jsonOutput: jsonOutput)
        }
    }
}

// MARK: - Refactored Helper Methods

@MainActor
private func resolvePoint(
    from elementId: String? = nil,
    coords: String? = nil,
    toApp appName: String? = nil,
    session: String? = nil
) async throws -> CGPoint {
    
    if let coordinates = coords {
        return try parseCoordinates(coordinates)
    } else if let element = elementId {
        // Resolve from session
        let sessionId = try await resolveSessionId(session)
        let sessionCache = try SessionCache(sessionId: sessionId)
        
        guard let sessionData = await sessionCache.load() else {
            throw DragError.sessionNotFound(sessionId)
        }
        
        guard let elementData = sessionData.uiMap[element] else {
            throw DragError.elementNotFound(element, sessionId)
        }
        
        // Recreate element and get current position
        let app = try ApplicationFinder.findApplication(identifier: sessionData.applicationName ?? "")
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // NEW: Use query API to find element by properties
        let foundElement = appElement.query()
            .role(elementData.role)
            .custom { el in
                // Match by position and title
                if let pos = el.position() {
                    let distance = sqrt(
                        pow(pos.x - elementData.frame.origin.x, 2) +
                        pow(pos.y - elementData.frame.origin.y, 2)
                    )
                    return distance < 10 && el.title() == elementData.title
                }
                return false
            }
            .first()
        
        guard let element = foundElement else {
            throw DragError.elementNotFound(element, sessionId)
        }
        
        // NEW: Wait for element to be actionable
        try await element.waitUntilActionable()
        
        guard let frame = element.frame() else {
            throw DragError.elementHasNoPosition(element)
        }
        
        return CGPoint(x: frame.midX, y: frame.midY)
        
    } else if let app = appName {
        return try await findApplicationPointRefactored(app)
    }
    
    throw DragError.noPointSpecified
}

@MainActor
private func findApplicationPointRefactored(_ appName: String) async throws -> CGPoint {
    // Special handling for Trash
    if appName.lowercased() == "trash" {
        // NEW: Use query API to find Trash in Dock
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.apple.dock" 
        }) else {
            throw DragError.dockNotFound
        }
        
        let dockElement = Element(AXUIElementCreateApplication(dockApp.processIdentifier))
        
        let trashItem = dockElement.query()
            .role("AXDockItem")
            .titleContains("Trash")
            .first()
        
        guard let trash = trashItem,
              let pos = trash.position() else {
            throw DragError.positionNotFound("Trash")
        }
        
        return pos
    }
    
    // For other apps, find their window
    let app = try ApplicationFinder.findApplication(identifier: appName)
    let appElement = Element(AXUIElementCreateApplication(app.processIdentifier))
    
    // NEW: Use query to find frontmost window
    guard let window = appElement.query()
        .role("AXWindow")
        .custom { $0.isMain() ?? false }
        .first() ?? appElement.query().role("AXWindow").first() else {
        throw DragError.noWindowsFound(appName)
    }
    
    guard let frame = window.frame() else {
        throw DragError.positionNotFound(appName)
    }
    
    return CGPoint(x: frame.midX, y: frame.midY)
}

private func parseModifiersRefactored(_ modifierString: String?) -> [ModifierKey] {
    guard let modifiers = modifierString else { return [] }
    let keys = modifiers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return ModifierKey.from(keys: keys)
}

// MARK: - Example of State Monitoring

@MainActor
private func performDragWithMonitoring(
    from startElement: Element,
    to endElement: Element,
    duration: TimeInterval
) async throws {
    // NEW: Monitor state changes during drag
    let monitor = ElementState.monitor(startElement, for: [.frame, .visibility]) { state, changes in
        if changes.contains(.visibility) && !state.isVisible {
            print("⚠️ Source element became invisible during drag")
        }
        if changes.contains(.frame) {
            print("⚠️ Source element moved during drag")
        }
    }
    
    defer { monitor.stop() }
    
    // Perform the drag
    guard let startFrame = startElement.frame(),
          let endFrame = endElement.frame() else {
        throw DragError.elementHasNoPosition("element")
    }
    
    EventSynthesizer.drag(
        from: CGPoint(x: startFrame.midX, y: startFrame.midY),
        to: CGPoint(x: endFrame.midX, y: endFrame.midY),
        duration: duration
    )
}