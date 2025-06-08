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
    let xCoordinate: Int
    let yCoordinate: Int
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
    case screenRecordingPermissionDenied
    case accessibilityPermissionDenied
    case invalidDisplayID
    case captureCreationFailed
    case windowNotFound
    case windowCaptureFailed
    case fileWriteError(String, Error?)
    case appNotFound(String)
    case invalidWindowIndex(Int)
    case invalidArgument(String)
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for capture."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required. " +
                "Please grant it in System Settings > Privacy & Security > Screen Recording."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for some operations. " +
                "Please grant it in System Settings > Privacy & Security > Accessibility."
        case .invalidDisplayID:
            return "Invalid display ID provided."
        case .captureCreationFailed:
            return "Failed to create the screen capture."
        case .windowNotFound:
            return "The specified window could not be found."
        case .windowCaptureFailed:
            return "Failed to capture the specified window."
        case let .fileWriteError(path, underlyingError):
            var message = "Failed to write capture file to path: \(path)."
            
            if let error = underlyingError {
                let errorString = error.localizedDescription
                if errorString.lowercased().contains("permission") {
                    message += " Permission denied - check that the directory is writable and the application has necessary permissions."
                } else if errorString.lowercased().contains("no such file") {
                    message += " Directory does not exist - ensure the parent directory exists."
                } else if errorString.lowercased().contains("no space") {
                    message += " Insufficient disk space available."
                } else {
                    message += " \(errorString)"
                }
            } else {
                message += " This may be due to insufficient permissions, missing directory, or disk space issues."
            }
            
            return message
        case let .appNotFound(identifier):
            return "Application with identifier '\(identifier)' not found or is not running."
        case let .invalidWindowIndex(index):
            return "Invalid window index: \(index)."
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .unknownError(message):
            return "An unexpected error occurred: \(message)"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .noDisplaysAvailable: 10
        case .screenRecordingPermissionDenied: 11
        case .accessibilityPermissionDenied: 12
        case .invalidDisplayID: 13
        case .captureCreationFailed: 14
        case .windowNotFound: 15
        case .windowCaptureFailed: 16
        case .fileWriteError(_, _): 17
        case .appNotFound: 18
        case .invalidWindowIndex: 19
        case .invalidArgument: 20
        case .unknownError: 1
        }
    }
}
