import Foundation

struct PermissionErrorDetector: Sendable {
    static func isScreenRecordingPermissionError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Check for specific screen recording related errors
        if errorString.contains("screen recording") {
            return true
        }

        // Check for NSError codes specific to screen capture permissions
        if let nsError = error as NSError? {
            // ScreenCaptureKit specific error codes
            if nsError.domain == "com.apple.screencapturekit" && nsError.code == -3801 {
                // SCStreamErrorUserDeclined = -3801
                return true
            }

            // CoreGraphics error codes for screen capture
            if nsError.domain == "com.apple.coregraphics" && nsError.code == 1002 {
                // kCGErrorCannotComplete when permissions are denied
                return true
            }
        }

        // Only consider it a permission error if it mentions both "permission" and capture-related terms
        if errorString.contains("permission") &&
            (errorString.contains("capture") || errorString.contains("recording") || errorString.contains("screen")) {
            return true
        }

        return false
    }
}
