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
            let screenCaptureKitDomains = [
                "com.apple.screencapturekit",
                "com.apple.screencapturekit.stream",
                "SCStreamErrorDomain"
            ]
            
            if screenCaptureKitDomains.contains(nsError.domain) {
                // SCStreamErrorUserDeclined = -3801, SCStreamErrorSystemDenied = -3802
                if nsError.code == -3801 || nsError.code == -3802 {
                    return true
                }
            }

            // CoreGraphics error codes for screen capture
            if nsError.domain == "com.apple.coregraphics" && nsError.code == 1002 {
                // kCGErrorCannotComplete when permissions are denied
                return true
            }
            
            // CGWindow errors
            if nsError.domain == "com.apple.coreanimation" && nsError.code == 32 {
                return true
            }
            
            // Security error domain with specific code
            if nsError.domain == "NSOSStatusErrorDomain" && nsError.code == -25201 {
                // errSecPrivacyViolation
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
