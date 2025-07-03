import ArgumentParser
import Foundation

// MARK: - Image Capture Models

/// Represents a saved screenshot file with its metadata.
///
/// Contains information about the captured image including its location,
/// window details, and MIME type for proper handling in responses.
struct SavedFile: Codable, Sendable {
    let path: String
    let item_label: String?
    let window_title: String?
    let window_id: UInt32?
    let window_index: Int?
    let mime_type: String
}

/// Container for image capture results.
///
/// Wraps an array of saved files produced during a capture operation,
/// supporting multi-window and multi-screen captures.
struct ImageCaptureData: Codable, Sendable {
    let saved_files: [SavedFile]
}

/// Defines the capture target mode for screenshot operations.
///
/// Determines what content will be captured: entire screens, specific windows,
/// multiple windows, or the currently active window.
enum CaptureMode: String, CaseIterable, ExpressibleByArgument, Sendable {
    case screen
    case window
    case multi
    case frontmost
}

/// Supported image formats for screenshot output.
///
/// Defines the file format for saved screenshots, affecting file size
/// and quality characteristics.
enum ImageFormat: String, CaseIterable, ExpressibleByArgument, Sendable {
    case png
    case jpg
}

/// Window focus behavior during capture operations.
///
/// Controls whether and how windows are brought to the foreground
/// before capturing, affecting screenshot content and user experience.
enum CaptureFocus: String, CaseIterable, ExpressibleByArgument, Sendable {
    case background
    case auto
    case foreground
}

// MARK: - Application & Window Models

/// Information about a running application.
///
/// Contains metadata about an application including its name, bundle identifier,
/// process ID, activation state, and number of windows.
struct ApplicationInfo: Codable, Sendable {
    let app_name: String
    let bundle_id: String
    let pid: Int32
    let is_active: Bool
    let window_count: Int
}

/// Container for application list results.
///
/// Wraps an array of ApplicationInfo objects returned when listing
/// all running applications on the system.
struct ApplicationListData: Codable, Sendable {
    let applications: [ApplicationInfo]
}

/// Information about a window.
///
/// Contains details about a window including its title, unique identifier,
/// position in the window list, bounds, and visibility status.
struct WindowInfo: Codable, Sendable {
    let window_title: String
    let window_id: UInt32?
    let window_index: Int?
    let bounds: WindowBounds?
    let is_on_screen: Bool?
}

/// Window position and dimensions.
///
/// Represents the rectangular bounds of a window on screen,
/// including its origin point (x, y) and size (width, height).
struct WindowBounds: Codable, Sendable {
    let x: Int // swiftlint:disable:this identifier_name
    let y: Int // swiftlint:disable:this identifier_name
    let width: Int
    let height: Int
}

/// Basic information about a target application.
///
/// A simplified application info structure used in window list responses
/// to identify the owning application.
struct TargetApplicationInfo: Codable, Sendable {
    let app_name: String
    let bundle_id: String?
    let pid: Int32
}

/// Container for window list results.
///
/// Contains an array of windows belonging to a specific application,
/// along with information about the target application.
struct WindowListData: Codable, Sendable {
    let windows: [WindowInfo]
    let target_application_info: TargetApplicationInfo
}

// MARK: - Window Specifier

/// Specifies how to identify a window for operations.
///
/// Windows can be identified either by their title (with fuzzy matching)
/// or by their index in the window list.
enum WindowSpecifier: Sendable {
    case title(String)
    case index(Int)
}

// MARK: - Window Details Options

/// Options for including additional window details.
///
/// Controls which optional window properties are included when listing windows,
/// allowing users to request additional information like bounds or off-screen status.
enum WindowDetailOption: String, CaseIterable, Sendable {
    case off_screen
    case bounds
    case ids
}

// MARK: - Window Management

/// Internal window representation with complete details.
///
/// Used internally for window operations, containing all available
/// information about a window including its Core Graphics identifier and bounds.
struct WindowData: Sendable {
    let windowId: UInt32
    let title: String
    let bounds: CGRect
    let isOnScreen: Bool
    let windowIndex: Int
}

// MARK: - Error Types

/// Errors that can occur during capture operations.
///
/// Comprehensive error enumeration covering all failure modes in screenshot capture,
/// window management, and file operations, with user-friendly error messages.
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
        }
    }
}
