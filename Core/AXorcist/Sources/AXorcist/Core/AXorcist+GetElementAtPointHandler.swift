import ApplicationServices
import Foundation

@MainActor
public extension AXorcist {
    func handleGetElementAtPoint(command: GetElementAtPointCommand) -> AXResponse {
        self.logGetPointRequest(command)

        guard let appElement = self.applicationElement(for: command) else {
            return self.applicationContextError(command: command)
        }

        self.logContextElement(appElement)

        let pid: pid_t = command.pid.map(pid_t.init) ?? appElement.pid() ?? 0
        guard let element = Element.elementAtPoint(command.point, pid: pid) else {
            return self.noElementResponse(command: command)
        }

        self.logLocatedElement(element)
        return .successResponse(payload: AnyCodable(self.elementData(from: element)))
    }

    private func logGetPointRequest(_ command: GetElementAtPointCommand) {
        let target = command.appIdentifier ?? "focused"
        let point = "[\(command.point.x), \(command.point.y)]"
        let pidDescription = command.pid.map(String.init) ?? "0"
        let message = "HandleGetElementAtPoint: App '\(target)', Point: \(point), PID: \(pidDescription)"
        GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: message))
    }

    private func applicationElement(for command: GetElementAtPointCommand) -> Element? {
        getApplicationElement(for: command.appIdentifier ?? "focused")
    }

    private func applicationContextError(command: GetElementAtPointCommand) -> AXResponse {
        let target = command.appIdentifier ?? "focused"
        let message = """
        HandleGetElementAtPoint: Could not get application element for '\(target)'.
        Application context is required even though elementAtPoint is system-wide.
        """
        .trimmingCharacters(in: .whitespacesAndNewlines)
        GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: message))
        return .errorResponse(message: message, code: .elementNotFound)
    }

    private func logContextElement(_ element: Element) {
        let description = element.briefDescription(option: .smart)
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: "Context app element: \(description)"))
    }

    private func noElementResponse(command: GetElementAtPointCommand) -> AXResponse {
        let target = command.appIdentifier ?? "focused"
        let point = "[\(command.point.x), \(command.point.y)]"
        let message = "No UI element found at \(point) for app '\(target)'."
        GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: message))
        let payload = NoElementAtPointPayload(message: message, element: nil)
        return .successResponse(payload: AnyCodable(payload))
    }

    private func logLocatedElement(_ element: Element) {
        let description = element.briefDescription(option: .smart)
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: "Element at point: \(description)"))
    }

    private func elementData(from element: Element) -> AXElementData {
        AXElementData(
            briefDescription: element.briefDescription(option: .smart),
            role: element.role(),
            attributes: [:],
            allPossibleAttributes: element.attributeNames(),
            textualContent: nil,
            childrenBriefDescriptions: nil,
            fullAXDescription: element.briefDescription(option: .stringified),
            path: element.generatePathString().components(separatedBy: " -> ")
        )
    }
}

private struct NoElementAtPointPayload: Codable {
    let message: String
    let element: AXElementData?
}
