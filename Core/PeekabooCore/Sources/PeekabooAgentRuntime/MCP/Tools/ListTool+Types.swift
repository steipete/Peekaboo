import Algorithms
import Foundation
import MCP
import PeekabooAutomation
import TachikomaMCP

enum RunningApplicationTextFormatter {
    static func format(_ app: ServiceApplicationInfo, index: Int) -> String {
        var entry = "\(index + 1). \(app.name)"
        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
            entry += " (\(bundleID))"
        }
        if let bundlePath = app.bundlePath, !bundlePath.isEmpty {
            entry += " [\(bundlePath)]"
        }
        entry += " - PID: \(app.processIdentifier)"
        if app.isActive {
            entry += " [ACTIVE]"
        }
        if app.isHidden {
            entry += " [HIDDEN]"
        }
        entry += " - Windows: \(app.windowCount)"
        return entry
    }

    static func activeLine(_ app: ServiceApplicationInfo) -> String {
        var activeLine = "\nActive application: \(app.name)"
        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
            activeLine += " (\(bundleID))"
        }
        return activeLine
    }
}

enum ListItemType: String, CaseIterable {
    case runningApplications = "running_applications"
    case applicationWindows = "application_windows"
    case serverStatus = "server_status"
}

enum WindowDetail: String, CaseIterable {
    case ids
    case bounds
    case offScreen = "off_screen"
}

enum ListInputError: Error {
    case missingApp
    case invalidDetail(String)

    var message: String {
        switch self {
        case .missingApp:
            "For 'application_windows', the 'app' parameter is required."
        case let .invalidDetail(value):
            "Unknown value in 'include_window_details': \(value)."
        }
    }
}

struct ListRequest {
    let itemType: ListItemType
    let app: String?
    let windowDetails: Set<WindowDetail>

    init(arguments: ToolArguments) throws {
        let app = arguments.getString("app")
        self.app = app

        if let typeString = arguments.getString("item_type"),
           let type = ListItemType(rawValue: typeString)
        {
            self.itemType = type
        } else {
            self.itemType = app != nil ? .applicationWindows : .runningApplications
        }

        if self.itemType == .applicationWindows, app == nil {
            throw ListInputError.missingApp
        }

        let rawDetails = arguments.getStringArray("include_window_details") ?? []
        var parsed: Set<WindowDetail> = []
        for raw in rawDetails {
            guard let detail = WindowDetail(rawValue: raw) else {
                throw ListInputError.invalidDetail(raw)
            }
            parsed.insert(detail)
        }
        self.windowDetails = parsed
    }
}

struct WindowListFormatter {
    let appInfo: ServiceApplicationInfo?
    let identifier: String
    let windows: [ServiceWindowInfo]
    let details: Set<WindowDetail>

    func response() -> ToolResponse {
        var lines = self.headerLines()
        lines.append("")
        lines.append(contentsOf: self.windowLines())
        let baseMeta: Value = .object([
            "window_count": .int(self.windows.count),
            "app": self.appInfo?.name != nil ? .string(self.appInfo!.name) : .string(self.identifier),
        ])
        let summary = ToolEventSummary(
            targetApp: self.appInfo?.name ?? self.identifier,
            actionDescription: "List Windows",
            notes: "\(self.windows.count) windows")
        return ToolResponse.text(
            lines.joined(separator: "\n"),
            meta: ToolEventSummary.merge(summary: summary, into: baseMeta))
    }

    private func headerLines() -> [String] {
        var lines: [String] = []
        let windowLabel = self.windows.count == 1 ? "window" : "windows"
        let countLine = "\(AgentDisplayTokens.Status.success) Found \(self.windows.count) \(windowLabel)"
        if let info = appInfo {
            var line = countLine + " for \(info.name)"
            if let bundleID = info.bundleIdentifier, !bundleID.isEmpty {
                line += " (\(bundleID))"
            }
            line += " - PID: \(info.processIdentifier)"
            lines.append(line)
        } else {
            lines.append(countLine + " for \(self.identifier)")
        }
        return lines
    }

    private func windowLines() -> [String] {
        guard !self.windows.isEmpty else {
            return ["No windows found"]
        }

        var lines = ["Windows:"]
        for (index, window) in self.windows.indexed() {
            var entry = "\(index + 1). \"\(window.title)\""
            let detailText = self.detailDescription(for: window)
            if !detailText.isEmpty {
                entry += " \(detailText)"
            }
            lines.append(entry)
        }
        return lines
    }

    private func detailDescription(for window: ServiceWindowInfo) -> String {
        var parts: [String] = []
        if self.details.contains(.ids), window.windowID != 0 {
            parts.append("ID: \(window.windowID)")
        }
        if self.details.contains(.offScreen) {
            parts.append(window.isOffScreen ? "OFF-SCREEN" : "ON-SCREEN")
        }
        if self.details.contains(.bounds) {
            let bounds = window.bounds
            let text = "Bounds: \(Int(bounds.origin.x)), \(Int(bounds.origin.y)) " +
                "\(Int(bounds.width))×\(Int(bounds.height))"
            parts.append(text)
        }
        guard !parts.isEmpty else { return "" }
        return "[" + parts.joined(separator: ", ") + "]"
    }
}

/// Extension to get processor architecture
extension ProcessInfo {
    nonisolated var processorArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
