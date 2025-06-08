import ArgumentParser
import Foundation

// MARK: - Image Capture Models

struct SavedFile: Codable, Sendable {
    let path: String
    let item_label: String?
    let window_title: String?
    let window_id: UInt32?
    let window_index: Int?
    let mime_type: String
}

struct ImageCaptureData: Codable, Sendable {
    let saved_files: [SavedFile]
}

enum CaptureMode: String, CaseIterable, ExpressibleByArgument, Sendable {
    case screen
    case window
    case multi
    case frontmost
    
    init?(argument: String) {
        self.init(rawValue: argument)
    }
}

enum ImageFormat: String, CaseIterable, ExpressibleByArgument, Sendable {
    case png
    case jpg
    
    init?(argument: String) {
        self.init(rawValue: argument)
    }
}

enum CaptureFocus: String, CaseIterable, ExpressibleByArgument, Sendable {
    case background
    case auto
    case foreground
    
    init?(argument: String) {
        self.init(rawValue: argument)
    }
}

// MARK: - Application & Window Models

struct ApplicationInfo: Codable, Sendable {
    let app_name: String
    let bundle_id: String
    let pid: Int32
    let is_active: Bool
    let window_count: Int
}

struct ApplicationListData: Codable, Sendable {
    let applications: [ApplicationInfo]
}

struct WindowInfo: Codable, Sendable {
    let window_title: String
    let window_id: UInt32?
    let window_index: Int?
    let bounds: WindowBounds?
    let is_on_screen: Bool?
}

struct WindowBounds: Codable, Sendable {
    let x_coordinate: Int
    let y_coordinate: Int
    let width: Int
    let height: Int

    private enum CodingKeys: String, CodingKey {
        case x_coordinate
        case y_coordinate
        case width
        case height
    }
}

struct TargetApplicationInfo: Codable, Sendable {
    let app_name: String
    let bundle_id: String?
    let pid: Int32
}

struct WindowListData: Codable, Sendable {
    let windows: [WindowInfo]
    let target_application_info: TargetApplicationInfo
}

// MARK: - Window Specifier

enum WindowSpecifier: Sendable {
    case title(String)
    case index(Int)
}

// MARK: - Window Details Options

enum WindowDetailOption: String, CaseIterable, Sendable {
    case off_screen
    case bounds
    case ids
}

// MARK: - Window Management

struct WindowData: Sendable {
    let windowId: UInt32
    let title: String
    let bounds: CGRect
    let isOnScreen: Bool
    let windowIndex: Int
}

// MARK: - Error Types

enum CaptureError: Error, LocalizedError, Sendable {
    case noDisplaysAvailable
    case screenRecordingPermissionDenied
    case accessibilityPermissionDenied
    case invalidDisplayID
    case captureCreationFailed(Error?)
    case windowNotFound
    case windowTitleNotFound(String, String, String) // searchTerm, appName, availableTitles
    case windowCaptureFailed(Error?)
    case fileWriteError(String, Error?)
    case appNotFound(String)
    case invalidWindowIndex(Int)
    case invalidArgument(String)
    case unknownError(String)
    case noWindowsFound(String)
    // Cross-platform errors
    case platformNotSupported(String)
    case featureNotSupported(String, String) // feature, platform

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
        case let .captureCreationFailed(underlyingError):
            var message = "Failed to create the screen capture."
            if let error = underlyingError {
                message += " \(error.localizedDescription)"
            }
            return message
        case .windowNotFound:
            return "The specified window could not be found."
        case let .windowTitleNotFound(searchTerm, appName, availableTitles):
            var message = "Window with title containing '\(searchTerm)' not found in \(appName)."
            if !availableTitles.isEmpty {
                message += " Available windows: \(availableTitles)."
            }
            message +=
                " Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080')."
            return message
        case let .windowCaptureFailed(underlyingError):
            var message = "Failed to capture the specified window."
            if let error = underlyingError {
                message += " \(error.localizedDescription)"
            }
            return message
        case let .fileWriteError(path, underlyingError):
            var message = "Failed to write capture file to path: \(path)."

            if let error = underlyingError {
                let errorString = error.localizedDescription
                if errorString.lowercased().contains("permission") {
                    message += " Permission denied - check that the directory is " +
                        "writable and the application has necessary permissions."
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
        case let .noWindowsFound(appName):
            return "The '\(appName)' process is running, but no capturable windows were found."
        case let .platformNotSupported(platform):
            return "Peekaboo is not supported on \(platform). Supported platforms: macOS, Windows, Linux."
        case let .featureNotSupported(feature, platform):
            return "\(feature) is not supported on \(platform)."
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
        case .windowTitleNotFound: 21
        case .windowCaptureFailed: 16
        case .fileWriteError: 17
        case .appNotFound: 18
        case .invalidWindowIndex: 19
        case .invalidArgument: 20
        case .unknownError: 1
        case .noWindowsFound: 7
        case .platformNotSupported: 22
        case .featureNotSupported: 23
        }
    }
}
