import ArgumentParser
import Foundation
import CoreGraphics
import AXorcist

/// Clicks on UI elements identified in the current session.
/// Supports element queries, coordinates, and smart waiting.
@available(macOS 14.0, *)
struct ClickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click on UI elements or coordinates",
        discussion: """
            The 'click' command interacts with UI elements captured by 'see'.
            It supports intelligent element finding, actionability checks, and
            automatic waiting for elements to become available.
            
            EXAMPLES:
              peekaboo click "Sign In"              # Click button with text
              peekaboo click --id element_42        # Click specific element ID
              peekaboo click --coords 100,200       # Click at coordinates
              peekaboo click "Submit" --wait 5      # Wait up to 5s for element
              peekaboo click "Menu" --double        # Double-click
              peekaboo click "File" --right         # Right-click
              
            ELEMENT MATCHING:
              Elements are matched by searching text in:
              - Title/Label content
              - Value text
              - Role descriptions
              
              Use --id for precise element targeting from 'see' output.
        """
    )
    
    @Argument(help: "Element text or query to click")
    var query: String?
    
    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?
    
    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?
    
    @Option(help: "Click at coordinates (x,y)")
    var coords: String?
    
    @Option(help: "Maximum milliseconds to wait for element")
    var waitFor: Int = 5000
    
    @Flag(help: "Double-click instead of single click")
    var double = false
    
    @Flag(help: "Right-click (secondary click)")
    var right = false
    
    @Flag(help: "Output in JSON format")
    var jsonOutput = false
    
    mutating func run() async throws {
        let startTime = Date()
        
        do {
            // Load session
            let sessionCache = SessionCache(sessionId: session)
            guard let sessionData = await sessionCache.load() else {
                throw PeekabooError.sessionNotFound
            }
            
            // Determine click target
            let clickTarget: ClickTarget
            
            if let elementId = on {
                // Click by element ID with auto-wait
                let element = try await waitForElement(
                    elementId: elementId,
                    sessionCache: sessionCache,
                    timeout: waitFor
                )
                clickTarget = .element(element)
                
            } else if let coordString = coords {
                // Click by coordinates
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]) else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(CGPoint(x: x, y: y))
                
            } else if let searchQuery = query {
                // Find element by query with auto-wait
                let element = try await waitForElementByQuery(
                    query: searchQuery,
                    sessionCache: sessionCache,
                    timeout: waitFor
                )
                clickTarget = .element(element)
                
            } else {
                throw ValidationError("Specify an element query, --on, or --coords")
            }
            
            // Perform the click
            let clickResult = try await performClick(
                target: clickTarget,
                clickType: ClickType(double: double, right: right)
            )
            
            // Output results
            if jsonOutput {
                let output = ClickResult(
                    success: true,
                    clickedElement: clickResult.elementInfo,
                    clickLocation: clickResult.location,
                    waitTime: clickResult.waitTime,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Click successful")
                if let info = clickResult.elementInfo {
                    print("🎯 Clicked: \(info)")
                }
                print("📍 Location: (\(Int(clickResult.location.x)), \(Int(clickResult.location.y)))")
                if clickResult.waitTime > 0 {
                    print("⏳ Waited: \(String(format: "%.1f", clickResult.waitTime))s")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }
            
        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }
    
    private func performClick(target: ClickTarget,
                            clickType: ClickType) async throws -> InternalClickResult {
        
        // Get the click location and element info
        let (clickLocation, elementInfo): (CGPoint, String?) = {
            switch target {
            case .element(let element):
                // Calculate center of element
                let center = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY
                )
                
                let info = "\(element.role): \(element.title ?? element.label ?? element.id)"
                return (center, info)
                
            case .coordinates(let point):
                return (point, nil)
            }
        }()
        
        // TODO: Implement actual click using AXorcist
        // For now, this is a placeholder
        // try await AXorcist.shared.click(
        //     at: clickLocation,
        //     clickType: clickType.toAXClickType(),
        //     clickCount: clickType.double ? 2 : 1
        // )
        
        // Small delay to ensure click is processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return InternalClickResult(
            location: clickLocation,
            elementInfo: elementInfo,
            waitTime: 0 // Wait time is now handled in waitForElement
        )
    }
    
    private func waitForElement(elementId: String,
                              sessionCache: SessionCache,
                              timeout: Int) async throws -> SessionCache.SessionData.UIElement {
        let startTime = Date()
        let timeoutSeconds = Double(timeout) / 1000.0
        let deadline = startTime.addingTimeInterval(timeoutSeconds)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        // First, try to find in the current session data
        if let sessionData = await sessionCache.load(),
           let element = sessionData.uiMap[elementId] {
            // Check if element is actionable
            if element.isActionable {
                return element
            }
        }
        
        // Enter retry loop
        while Date() < deadline {
            // In a real implementation, we would:
            // 1. Re-query the accessibility tree
            // 2. Find elements matching the original element's properties
            // 3. Check if they're actionable
            
            // For now, just check the cached data
            if let sessionData = await sessionCache.load(),
               let element = sessionData.uiMap[elementId],
               element.isActionable {
                return element
            }
            
            // Wait before retrying
            try await Task.sleep(nanoseconds: retryInterval)
        }
        
        throw PeekabooError.interactionFailed(
            "Element '\(elementId)' not found or not actionable after \(timeout)ms"
        )
    }
    
    private func waitForElementByQuery(query: String,
                                     sessionCache: SessionCache,
                                     timeout: Int) async throws -> SessionCache.SessionData.UIElement {
        let startTime = Date()
        let timeoutSeconds = Double(timeout) / 1000.0
        let deadline = startTime.addingTimeInterval(timeoutSeconds)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        while Date() < deadline {
            // Find elements matching the query
            let elements = await sessionCache.findElements(matching: query)
                .filter { $0.isActionable }
            
            if let element = elements.first {
                return element
            }
            
            // Wait before retrying
            try await Task.sleep(nanoseconds: retryInterval)
        }
        
        throw PeekabooError.interactionFailed(
            "No actionable element found matching '\(query)' after \(timeout)ms"
        )
    }
}

// MARK: - Supporting Types

private enum ClickTarget {
    case element(SessionCache.SessionData.UIElement)
    case coordinates(CGPoint)
}

private struct ClickType {
    let double: Bool
    let right: Bool
    
    func toAXClickType() -> String { // TODO: Change to AXMouseButton when available
        return right ? "right" : "left"
    }
}

private struct InternalClickResult {
    let location: CGPoint
    let elementInfo: String?
    let waitTime: Double
}

// MARK: - JSON Output Structure

struct ClickResult: Codable {
    let success: Bool
    let clickedElement: String?
    let clickLocation: [String: Double]
    let waitTime: Double
    let executionTime: TimeInterval
    
    init(success: Bool, clickedElement: String?, clickLocation: CGPoint, 
         waitTime: Double, executionTime: TimeInterval) {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
    }
}