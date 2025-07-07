import Foundation

// MARK: - Image Capture Models

/// Represents a saved screenshot file with its metadata.
///
/// Contains information about the captured image including its location,
/// window details, and MIME type for proper handling in responses.
public struct SavedFile: Codable, Sendable {
    public let path: String
    public let item_label: String?
    public let window_title: String?
    public let window_id: UInt32?
    public let window_index: Int?
    public let mime_type: String
    
    public init(
        path: String,
        item_label: String? = nil,
        window_title: String? = nil,
        window_id: UInt32? = nil,
        window_index: Int? = nil,
        mime_type: String
    ) {
        self.path = path
        self.item_label = item_label
        self.window_title = window_title
        self.window_id = window_id
        self.window_index = window_index
        self.mime_type = mime_type
    }
}

/// Container for image capture results.
///
/// Wraps an array of saved files produced during a capture operation,
/// supporting multi-window and multi-screen captures.
public struct ImageCaptureData: Codable, Sendable {
    public let saved_files: [SavedFile]
    
    public init(saved_files: [SavedFile]) {
        self.saved_files = saved_files
    }
}

/// Defines the capture target mode for screenshot operations.
///
/// Determines what content will be captured: entire screens, specific windows,
/// multiple windows, or the currently active window.
public enum CaptureMode: String, CaseIterable, Codable, Sendable {
    case screen
    case window
    case multi
    case frontmost
}

/// Supported image formats for screenshot output.
///
/// Defines the file format for saved screenshots, affecting file size
/// and quality characteristics.
public enum ImageFormat: String, CaseIterable, Codable, Sendable {
    case png
    case jpg
}

/// Window focus behavior during capture operations.
///
/// Controls whether and how windows are brought to the foreground
/// before capturing, affecting screenshot content and user experience.
public enum CaptureFocus: String, CaseIterable, Codable, Sendable {
    case background
    case auto
    case foreground
}