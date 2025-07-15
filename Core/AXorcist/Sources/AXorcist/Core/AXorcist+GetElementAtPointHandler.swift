import ApplicationServices // For CGPoint
import Foundation

@MainActor
public extension AXorcist {
    func handleGetElementAtPoint(command: GetElementAtPointCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleGetElementAtPoint: App '\(command.appIdentifier ?? "focused")', " +
                "Point: ([\(command.point.x), \(command.point.y)]), PID: \(command.pid ?? 0)"
        ))

        // Get the application element first to ensure the coordinate system context.
        // While elementAtPoint is system-wide, it's good practice to ensure app context if specified.
        guard let appElement = getApplicationElement(for: command.appIdentifier ?? "focused") else {
            let errorMessage = "HandleGetElementAtPoint: Could not get application element for " +
                "'\(command.appIdentifier ?? "focused")'. " +
                "This is needed for context, even if elementAtPoint is system-wide."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage,
                                  code: .elementNotFound) // Or perhaps a different error code if app context is just
            // preferred
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleGetElementAtPoint: Context app element: \(appElement.briefDescription(option: ValueFormatOption.smart))"
        ))

        let pid: pid_t = command.pid.map { pid_t($0) } ?? appElement.pid() ?? 0
        guard let elementAtPoint = Element.elementAtPoint(command.point, pid: pid) else {
            let errorMessage =
                "HandleGetElementAtPoint: No UI element found at point ([\(command.point.x), \(command.point.y)]) for app context '\(command.appIdentifier ?? "focused")'."
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: errorMessage))
            // This is not necessarily an error, could be a valid state (e.g., clicked on desktop).
            // Return success with an empty payload or specific indication.
            struct NoElementAtPointPayload: Codable {
                let message: String
                let element: AXElementData?
                init(message: String, element: AXElementData? = nil) {
                    self.message = message
                    self.element = element
                }
            }
            return .successResponse(
                payload: AnyCodable(NoElementAtPointPayload(message: "No UI element found at the specified point."))
            )
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleGetElementAtPoint: Element at point: \(elementAtPoint.briefDescription(option: ValueFormatOption.smart))"
        ))

        // Build a response with the element information
        let briefDescription = elementAtPoint.briefDescription(option: ValueFormatOption.smart)
        let role = elementAtPoint.role()

        let elementData = AXElementData(
            briefDescription: briefDescription,
            role: role,
            attributes: [:], // Could fetch attributes if needed
            allPossibleAttributes: elementAtPoint.attributeNames(),
            textualContent: nil,
            childrenBriefDescriptions: nil,
            fullAXDescription: elementAtPoint.briefDescription(option: ValueFormatOption.stringified),
            path: elementAtPoint.generatePathString().components(separatedBy: " -> ")
        )

        return .successResponse(payload: AnyCodable(elementData))
    }
}
