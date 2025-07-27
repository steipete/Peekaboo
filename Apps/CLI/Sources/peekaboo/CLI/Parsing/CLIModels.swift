import ArgumentParser
import Foundation
import PeekabooCore

// MARK: - Image Capture Models

// Re-export PeekabooCore types
typealias SavedFile = PeekabooCore.SavedFile
typealias ImageCaptureData = PeekabooCore.ImageCaptureData

// Extend PeekabooCore.CaptureMode to conform to ExpressibleByArgument for CLI usage
extension PeekabooCore.CaptureMode: @retroactive ExpressibleByArgument {}

// Extend PeekabooCore.ImageFormat to conform to ExpressibleByArgument for CLI usage
extension PeekabooCore.ImageFormat: @retroactive ExpressibleByArgument {}

// Extend PeekabooCore.CaptureFocus to conform to ExpressibleByArgument for CLI usage
extension PeekabooCore.CaptureFocus: @retroactive ExpressibleByArgument {}

// MARK: - Application & Window Models

// Re-export PeekabooCore types
typealias ApplicationInfo = PeekabooCore.ApplicationInfo
typealias ApplicationListData = PeekabooCore.ApplicationListData
typealias WindowInfo = PeekabooCore.WindowInfo
typealias WindowBounds = PeekabooCore.WindowBounds
typealias TargetApplicationInfo = PeekabooCore.TargetApplicationInfo
typealias WindowListData = PeekabooCore.WindowListData

// MARK: - Window Specifier

// Re-export WindowSpecifier from PeekabooCore
typealias WindowSpecifier = PeekabooCore.WindowSpecifier

// MARK: - Window Details Options

// Re-export WindowDetailOption from PeekabooCore
typealias WindowDetailOption = PeekabooCore.WindowDetailOption

// MARK: - Window Management

/// Internal window representation with complete details.
///
/// Used internally for window operations, containing all available
/// information about a window including its Core Graphics identifier and bounds.
/// This is CLI-specific and not shared with PeekabooCore.
struct WindowData: Sendable {
    let windowId: UInt32
    let title: String
    let bounds: CGRect
    let isOnScreen: Bool
    let windowIndex: Int
}

// MARK: - Error Types

// Re-export CaptureError from PeekabooCore
typealias CaptureError = PeekabooCore.CaptureError
