import Foundation
import PeekabooCore

struct FileNameGenerator: Sendable {
    static func generateFileName(
        displayIndex: Int? = nil,
        appName: String? = nil,
        windowIndex: Int? = nil,
        windowTitle: String? = nil,
        format: ImageFormat) -> String
    {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let ext = format.rawValue

        if let displayIndex {
            return "screen_\(displayIndex + 1)_\(timestamp).\(ext)"
        } else if let appName {
            let cleanAppName = appName.replacingOccurrences(of: " ", with: "_")
            if let windowIndex {
                return "\(cleanAppName)_window_\(windowIndex)_\(timestamp).\(ext)"
            } else if let windowTitle {
                let cleanTitle = windowTitle.replacingOccurrences(of: " ", with: "_").prefix(20)
                return "\(cleanAppName)_\(cleanTitle)_\(timestamp).\(ext)"
            } else {
                return "\(cleanAppName)_\(timestamp).\(ext)"
            }
        } else {
            return "capture_\(timestamp).\(ext)"
        }
    }
}

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
