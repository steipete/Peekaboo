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

/// Image capture result data
struct ImageCaptureData: Codable {
    let file_path: String
    let file_size_bytes: Int?
    let image_width: Int?
    let image_height: Int?
    let format: String
    let timestamp: String
    let target_application_info: TargetApplicationInfo?
    let captured_windows: [WindowInfoData]?
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

