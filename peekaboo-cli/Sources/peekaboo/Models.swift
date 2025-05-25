import ArgumentParser
import Foundation

// MARK: - Image Capture Models

struct SavedFile: Codable {
    let path: String
    let item_label: String?
    let window_title: String?
    let window_id: UInt32?
    let window_index: Int?
    let mime_type: String
}

struct ImageCaptureData: Codable {
    let saved_files: [SavedFile]
}

enum CaptureMode: String, CaseIterable, ExpressibleByArgument {
    case screen
    case window
    case multi
}

enum ImageFormat: String, CaseIterable, ExpressibleByArgument {
    case png
    case jpg
}

enum CaptureFocus: String, CaseIterable, ExpressibleByArgument {
    case background
    case foreground
}

// MARK: - Application & Window Models

struct ApplicationInfo: Codable {
    let app_name: String
    let bundle_id: String
    let pid: Int32
    let is_active: Bool
    let window_count: Int
}

struct ApplicationListData: Codable {
    let applications: [ApplicationInfo]
}

struct WindowInfo: Codable {
    let window_title: String
    let window_id: UInt32?
    let window_index: Int?
    let bounds: WindowBounds?
    let is_on_screen: Bool?
}

struct WindowBounds: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct TargetApplicationInfo: Codable {
    let app_name: String
    let bundle_id: String?
    let pid: Int32
}

struct WindowListData: Codable {
    let windows: [WindowInfo]
    let target_application_info: TargetApplicationInfo
}

// MARK: - Window Specifier

enum WindowSpecifier {
    case title(String)
    case index(Int)
}

// MARK: - Window Details Options

enum WindowDetailOption: String, CaseIterable {
    case off_screen
    case bounds
    case ids
}

// MARK: - Window Management

struct WindowData {
    let windowId: UInt32
    let title: String
    let bounds: CGRect
    let isOnScreen: Bool
    let windowIndex: Int
}

// MARK: - Error Types

enum CaptureError: Error, LocalizedError {
    case noDisplaysAvailable
    case capturePermissionDenied
    case invalidDisplayID
    case captureCreationFailed
    case windowNotFound
    case windowCaptureFailed
    case fileWriteError(String)
    case appNotFound(String)
    case invalidWindowIndex(Int)

    var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for capture"
        case .capturePermissionDenied:
            return "Screen recording permission denied. Please grant permission in " +
                "System Preferences > Security & Privacy > Privacy > Screen Recording"
        case .invalidDisplayID:
            return "Invalid display ID"
        case .captureCreationFailed:
            return "Failed to create screen capture"
        case .windowNotFound:
            return "Window not found"
        case .windowCaptureFailed:
            return "Failed to capture window"
        case let .fileWriteError(path):
            return "Failed to write file to: \(path)"
        case let .appNotFound(identifier):
            return "Application not found: \(identifier)"
        case let .invalidWindowIndex(index):
            return "Invalid window index: \(index)"
        }
    }
}
