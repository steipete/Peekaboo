import Foundation

// MARK: - Application Models

/// Information about a running application
struct ApplicationInfo: Codable {
    let name: String
    let bundle_id: String?
    let process_id: Int32
    let is_active: Bool
    let window_count: Int
}

/// Data structure for application list output
struct ApplicationListData: Codable {
    let applications: [ApplicationInfo]
}

/// Information about a target application
struct TargetApplicationInfo: Codable {
    let name: String
    let bundle_id: String?
    let process_id: Int32?
    let window_count: Int?
}

// MARK: - Window Models

/// Window bounds information for JSON output
struct WindowBoundsData: Codable {
    let xCoordinate: Int
    let yCoordinate: Int
    let width: Int
    let height: Int
}

/// Window information for JSON output
struct WindowInfoData: Codable {
    let window_title: String
    let window_id: UInt32?
    let window_index: Int?
    let bounds: WindowBoundsData?
    let is_on_screen: Bool?
}

/// Data structure for window list output
struct WindowListData: Codable {
    let windows: [WindowInfoData]
    let target_application_info: TargetApplicationInfo
}

// MARK: - Image Models

/// Saved file information
struct SavedFile: Codable {
    let path: String
    let size_bytes: Int?
    let width: Int?
    let height: Int?
    let format: String
}

/// Image capture result data
struct ImageCaptureData: Codable {
    let saved_files: [SavedFile]
    let file_path: String
    let file_size_bytes: Int?
    let image_width: Int?
    let image_height: Int?
    let format: String
    let timestamp: String
    let target_application_info: TargetApplicationInfo?
    let captured_windows: [WindowInfoData]?
    
    init(saved_files: [SavedFile]) {
        self.saved_files = saved_files
        // Use first file for backward compatibility
        if let firstFile = saved_files.first {
            self.file_path = firstFile.path
            self.file_size_bytes = firstFile.size_bytes
            self.image_width = firstFile.width
            self.image_height = firstFile.height
            self.format = firstFile.format
        } else {
            self.file_path = ""
            self.file_size_bytes = nil
            self.image_width = nil
            self.image_height = nil
            self.format = "png"
        }
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.target_application_info = nil
        self.captured_windows = nil
    }
}

// MARK: - Error Models

/// Error information for JSON output
struct ErrorData: Codable {
    let error_type: String
    let error_message: String
    let error_code: Int?
}

// MARK: - Success Response Models

/// Generic success response wrapper
struct SuccessResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let timestamp: String
    
    init(data: T) {
        self.success = true
        self.data = data
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

/// Generic error response wrapper
struct ErrorResponse: Codable {
    let success: Bool
    let error: ErrorData
    let timestamp: String
    
    init(error: ErrorData) {
        self.success = false
        self.error = error
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Enums

/// Capture mode options
enum CaptureMode: String, CaseIterable, Codable {
    case screen = "screen"
    case window = "window"
    case application = "application"
}

/// Image format options
enum ImageFormat: String, CaseIterable, Codable {
    case png = "png"
    case jpeg = "jpeg"
    case jpg = "jpg"
    case tiff = "tiff"
    case bmp = "bmp"
    case gif = "gif"
}

/// Capture focus behavior
enum CaptureFocus: String, CaseIterable, Codable {
    case auto = "auto"
    case foreground = "foreground"
    case background = "background"
}

/// Capture errors
enum CaptureError: Error, Codable {
    case unknownError(String)
    case appNotFound(String)
    case windowNotFound
    case screenRecordingPermissionDenied
    case invalidArgument(String)
    case systemError(String)
    
    var localizedDescription: String {
        switch self {
        case .unknownError(let message):
            return "Unknown error: \(message)"
        case .appNotFound(let app):
            return "Application not found: \(app)"
        case .windowNotFound:
            return "Window not found"
        case .screenRecordingPermissionDenied:
            return "Screen recording permission denied"
        case .invalidArgument(let arg):
            return "Invalid argument: \(arg)"
        case .systemError(let error):
            return "System error: \(error)"
        }
    }
}

// MARK: - Platform Image Format

/// Supported image formats across platforms
enum PlatformImageFormat: String, CaseIterable {
    case png = "png"
    case jpeg = "jpeg"
    case jpg = "jpg"
    case tiff = "tiff"
    case bmp = "bmp"
    case gif = "gif"
    
    /// Get the appropriate UTType identifier for the format
    var utType: String {
        switch self {
        case .png:
            return "public.png"
        case .jpeg, .jpg:
            return "public.jpeg"
        case .tiff:
            return "public.tiff"
        case .bmp:
            return "com.microsoft.bmp"
        case .gif:
            return "com.compuserve.gif"
        }
    }
    
    /// Get file extension for the format
    var fileExtension: String {
        return self.rawValue
    }
    
    /// Create from string, with fallback to PNG
    static func from(string: String) -> PlatformImageFormat {
        return PlatformImageFormat(rawValue: string.lowercased()) ?? .png
    }
    
    /// Convert from ImageFormat
    static func from(imageFormat: ImageFormat) -> PlatformImageFormat {
        return PlatformImageFormat(rawValue: imageFormat.rawValue) ?? .png
    }
}

// MARK: - Conversion Extensions

extension ApplicationInfo {
    /// Convert from RunningApplication
    init(from app: RunningApplication) {
        self.name = app.name
        self.bundle_id = app.bundleIdentifier
        self.process_id = app.processIdentifier
        self.is_active = app.isActive
        self.window_count = app.windowCount ?? 0
    }
}

extension WindowInfoData {
    /// Convert from WindowInfo protocol
    init(from window: WindowInfo, includeDetails: Bool = false) {
        self.window_title = window.window_title
        self.window_id = includeDetails ? window.window_id : nil
        self.window_index = includeDetails ? window.window_index : nil
        self.is_on_screen = includeDetails ? window.is_on_screen : nil
        
        if includeDetails, let bounds = window.bounds {
            self.bounds = WindowBoundsData(
                xCoordinate: bounds.xCoordinate,
                yCoordinate: bounds.yCoordinate,
                width: bounds.width,
                height: bounds.height
            )
        } else {
            self.bounds = nil
        }
    }
}

