import Foundation
import MCP

public struct ToolEventSummary: Codable, Sendable {
    public struct Coordinates: Codable, Sendable {
        public var x: Double?
        public var y: Double?

        public init(x: Double? = nil, y: Double? = nil) {
            self.x = x
            self.y = y
        }
    }

    public var targetApp: String?
    public var windowTitle: String?
    public var elementRole: String?
    public var elementLabel: String?
    public var elementValue: String?
    public var actionDescription: String?
    public var coordinates: Coordinates?
    public var pointerProfile: String?
    public var pointerDistance: Double?
    public var pointerDirection: String?
    public var pointerDurationMs: Double?
    public var scrollDirection: String?
    public var scrollAmount: Double?
    public var command: String?
    public var workingDirectory: String?
    public var waitDurationMs: Double?
    public var waitReason: String?
    public var captureApp: String?
    public var captureWindow: String?
    public var notes: String?

    public init(
        targetApp: String? = nil,
        windowTitle: String? = nil,
        elementRole: String? = nil,
        elementLabel: String? = nil,
        elementValue: String? = nil,
        actionDescription: String? = nil,
        coordinates: Coordinates? = nil,
        pointerProfile: String? = nil,
        pointerDistance: Double? = nil,
        pointerDirection: String? = nil,
        pointerDurationMs: Double? = nil,
        scrollDirection: String? = nil,
        scrollAmount: Double? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        waitDurationMs: Double? = nil,
        waitReason: String? = nil,
        captureApp: String? = nil,
        captureWindow: String? = nil,
        notes: String? = nil)
    {
        self.targetApp = targetApp
        self.windowTitle = windowTitle
        self.elementRole = elementRole
        self.elementLabel = elementLabel
        self.elementValue = elementValue
        self.actionDescription = actionDescription
        self.coordinates = coordinates
        self.pointerProfile = pointerProfile
        self.pointerDistance = pointerDistance
        self.pointerDirection = pointerDirection
        self.pointerDurationMs = pointerDurationMs
        self.scrollDirection = scrollDirection
        self.scrollAmount = scrollAmount
        self.command = command
        self.workingDirectory = workingDirectory
        self.waitDurationMs = waitDurationMs
        self.waitReason = waitReason
        self.captureApp = captureApp
        self.captureWindow = captureWindow
        self.notes = notes
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func toMetaValue() -> Value {
        var dict: [String: Value] = [:]
        if let targetApp { dict["target_app"] = .string(targetApp) }
        if let windowTitle { dict["window_title"] = .string(windowTitle) }
        if let elementRole { dict["element_role"] = .string(elementRole) }
        if let elementLabel { dict["element_label"] = .string(elementLabel) }
        if let elementValue { dict["element_value"] = .string(elementValue) }
        if let actionDescription { dict["action"] = .string(actionDescription) }
        if let coordinates {
            var coords: [String: Value] = [:]
            if let x = coordinates.x { coords["x"] = .double(x) }
            if let y = coordinates.y { coords["y"] = .double(y) }
            if !coords.isEmpty { dict["coordinates"] = .object(coords) }
        }
        if let pointerProfile { dict["pointer_profile"] = .string(pointerProfile) }
        if let pointerDistance { dict["pointer_distance"] = .double(pointerDistance) }
        if let pointerDirection { dict["pointer_direction"] = .string(pointerDirection) }
        if let pointerDurationMs { dict["pointer_duration_ms"] = .double(pointerDurationMs) }
        if let scrollDirection { dict["scroll_direction"] = .string(scrollDirection) }
        if let scrollAmount { dict["scroll_amount"] = .double(scrollAmount) }
        if let command { dict["command"] = .string(command) }
        if let workingDirectory { dict["working_directory"] = .string(workingDirectory) }
        if let waitDurationMs { dict["wait_duration_ms"] = .double(waitDurationMs) }
        if let waitReason { dict["wait_reason"] = .string(waitReason) }
        if let captureApp { dict["capture_app"] = .string(captureApp) }
        if let captureWindow { dict["capture_window"] = .string(captureWindow) }
        if let notes { dict["notes"] = .string(notes) }
        return .object(dict)
    }

    public static func merge(summary: ToolEventSummary, into existingMeta: Value?) -> Value {
        var payload: [String: Value] = [:]
        if case let .object(existing) = existingMeta {
            payload = existing
        }
        payload["summary"] = summary.toMetaValue()
        return .object(payload)
    }

    public init?(json: [String: Any]) {
        guard !json.isEmpty else { return nil }
        self.targetApp = json["target_app"] as? String
        self.windowTitle = json["window_title"] as? String
        self.elementRole = json["element_role"] as? String
        self.elementLabel = json["element_label"] as? String
        self.elementValue = json["element_value"] as? String
        self.actionDescription = json["action"] as? String
        if let coords = json["coordinates"] as? [String: Any] {
            let x = coords["x"] as? Double
            let y = coords["y"] as? Double
            if x != nil || y != nil {
                self.coordinates = Coordinates(x: x, y: y)
            }
        }
        self.pointerProfile = json["pointer_profile"] as? String
        self.pointerDistance = json["pointer_distance"] as? Double
        self.pointerDirection = json["pointer_direction"] as? String
        self.pointerDurationMs = json["pointer_duration_ms"] as? Double
        self.scrollDirection = json["scroll_direction"] as? String
        self.scrollAmount = json["scroll_amount"] as? Double
        self.command = json["command"] as? String
        self.workingDirectory = json["working_directory"] as? String
        self.waitDurationMs = json["wait_duration_ms"] as? Double
        self.waitReason = json["wait_reason"] as? String
        self.captureApp = json["capture_app"] as? String
        self.captureWindow = json["capture_window"] as? String
        self.notes = json["notes"] as? String
    }

    public static func from(resultJSON: [String: Any]) -> ToolEventSummary? {
        guard
            let meta = resultJSON["meta"] as? [String: Any],
            let summaryJSON = meta["summary"] as? [String: Any]
        else {
            return nil
        }
        return ToolEventSummary(json: summaryJSON)
    }

    public func shortDescription(toolName: String) -> String? {
        if let command {
            if let cwd = workingDirectory {
                return "Run `\(command)` in \(cwd)"
            }
            return "Run `\(command)`"
        }

        if let captureApp {
            if let captureWindow {
                return "Captured \(captureApp) · \(captureWindow)"
            }
            return "Captured \(captureApp)"
        }

        if let elementLabel {
            var segments: [String] = []
            if let targetApp { segments.append(targetApp) }

            var label = elementLabel
            if let elementRole {
                label += " (\(elementRole))"
            }
            segments.append(label)

            return segments.joined(separator: " · ")
        }

        if let targetApp, let actionDescription {
            return "\(actionDescription) – \(targetApp)"
        }

        if let targetApp {
            return targetApp
        }

        if let notes {
            return notes
        }

        if let waitDurationMs {
            let seconds = waitDurationMs / 1000.0
            if let reason = waitReason {
                return String(format: "Wait %.1fs (%@)", seconds, reason)
            }
            return String(format: "Wait %.1fs", seconds)
        }

        if let scrollDirection, let scrollAmount {
            return String(format: "Scrolled %@ %.0f px", scrollDirection, scrollAmount)
        }

        if let pointerDirection, let pointerDistance {
            return String(format: "Pointer %@ %.0f px", pointerDirection, pointerDistance)
        }

        return actionDescription
    }
}
