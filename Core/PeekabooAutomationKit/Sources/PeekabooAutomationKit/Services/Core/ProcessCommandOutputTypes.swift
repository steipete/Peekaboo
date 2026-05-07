import CoreGraphics
import Foundation

extension ProcessCommandOutput {
    public struct ScreenshotOutput: Codable, Sendable {
        public let path: String
        public let width: Int
        public let height: Int
        public let fileSize: Int64?

        public init(path: String, width: Int, height: Int, fileSize: Int64? = nil) {
            self.path = path
            self.width = width
            self.height = height
            self.fileSize = fileSize
        }
    }

    public struct ElementOutput: Codable, Sendable {
        public let label: String?
        public let identifier: String?
        public let type: String
        public let frame: CGRect
        public let isEnabled: Bool
        public let isFocused: Bool

        public init(
            label: String?,
            identifier: String?,
            type: String,
            frame: CGRect,
            isEnabled: Bool,
            isFocused: Bool)
        {
            self.label = label
            self.identifier = identifier
            self.type = type
            self.frame = frame
            self.isEnabled = isEnabled
            self.isFocused = isFocused
        }
    }

    public struct WindowOutput: Codable, Sendable {
        public let title: String?
        public let app: String
        public let frame: CGRect
        public let isMinimized: Bool
        public let isMainWindow: Bool
        public let screenIndex: Int?
        public let screenName: String?

        public init(
            title: String?,
            app: String,
            frame: CGRect,
            isMinimized: Bool,
            isMainWindow: Bool,
            screenIndex: Int? = nil,
            screenName: String? = nil)
        {
            self.title = title
            self.app = app
            self.frame = frame
            self.isMinimized = isMinimized
            self.isMainWindow = isMainWindow
            self.screenIndex = screenIndex
            self.screenName = screenName
        }
    }
}
