import Foundation
import Testing
@testable import peekaboo

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Suite("ImageErrorHandler Tests")
    struct ImageErrorHandlerTests {
        @Test("Handles standard output for errors")
        func standardErrorOutput() {
            let error = CaptureError.screenRecordingPermissionDenied

            // This will write to stderr, we just verify it doesn't crash
            ImageErrorHandler.handleError(error, jsonOutput: false)

            // The actual output goes to stderr which we can't easily capture in tests
            #expect(Bool(true))
        }

        @Test("Handles JSON output for errors")
        func jSONErrorOutput() {
            let error = CaptureError.appNotFound("NonExistentApp")

            // This will output JSON to stdout, we just verify it doesn't crash
            ImageErrorHandler.handleError(error, jsonOutput: true)

            #expect(Bool(true))
        }
    }

    @Suite("PermissionErrorDetector Tests")
    struct PermissionErrorDetectorTests {
        @Test("Detects screen recording permission errors", arguments: [
            "com.apple.screencapturekit.stream",
            "SCStreamErrorDomain",
        ])
        func detectsScreenRecordingErrors(errorDomain: String) {
            let error = NSError(
                domain: errorDomain,
                code: -3801,
                userInfo: nil
            )

            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(error) == true)
        }

        @Test("Detects CGWindow permission errors")
        func detectsCGWindowPermissionError() {
            let error = NSError(
                domain: NSOSStatusErrorDomain,
                code: -25201, // CGWindowListCreateImage permission error
                userInfo: nil
            )

            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(error) == true)
        }

        @Test("Does not detect non-permission errors")
        func doesNotDetectNonPermissionErrors() {
            let genericError = NSError(
                domain: "com.example.error",
                code: 123,
                userInfo: nil
            )

            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(genericError) == false)

            let wrongCode = NSError(
                domain: "com.apple.screencapturekit.stream",
                code: -1234, // Wrong code
                userInfo: nil
            )

            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(wrongCode) == false)
        }

        @Test("Handles non-NSError types")
        func handlesNonNSErrorTypes() {
            struct CustomError: Error {}
            let customError = CustomError()

            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(customError) == false)
        }

        @Test("Detects permission errors with various codes", arguments: [
            ("com.apple.screencapturekit.stream", -3801),
            ("com.apple.screencapturekit.stream", -3802),
            ("SCStreamErrorDomain", -3801),
            ("SCStreamErrorDomain", -3802),
            (NSOSStatusErrorDomain, -25201)
        ])
        func detectsVariousPermissionErrorCodes(domain: String, code: Int) {
            let error = NSError(domain: domain, code: code, userInfo: nil)
            #expect(PermissionErrorDetector.isScreenRecordingPermissionError(error) == true)
        }
    }

    @Suite("CaptureError Tests")
    struct CaptureErrorTests {
        @Test("Error descriptions are user-friendly")
        func errorDescriptions() {
            let errors: [(CaptureError, String)] = [
                (.screenRecordingPermissionDenied, "Screen recording permission is required"),
                (.accessibilityPermissionDenied, "Accessibility permission is required"),
                (.appNotFound("Safari"), "Application with identifier 'Safari' not found"),
                (.windowNotFound, "The specified window could not be found"),
                (.noWindowsFound("Finder"), "The 'Finder' process is running, but no capturable windows were found"),
                (.invalidWindowIndex(5, availableCount: 3), "Invalid window index: 5. Available windows: 3"),
                (.fileWriteError("/tmp/test.png", nil), "Failed to write capture file to path: /tmp/test.png"),
            ]

            for (error, expectedPrefix) in errors {
                let description = error.errorDescription ?? ""
                #expect(description.hasPrefix(expectedPrefix), "Error: \(error), Description: \(description)")
            }
        }

        @Test("Error exit codes are unique")
        func errorExitCodes() {
            let errors: [CaptureError] = [
                .noDisplaysAvailable,
                .screenRecordingPermissionDenied,
                .accessibilityPermissionDenied,
                .invalidDisplayID,
                .captureCreationFailed(nil),
                .windowNotFound,
                .appNotFound("test"),
                .invalidWindowIndex(0, availableCount: 0),
                .fileWriteError("test", nil),
            ]

            let exitCodes = errors.map(\.exitCode)
            let uniqueCodes = Set(exitCodes)

            #expect(exitCodes.count == uniqueCodes.count, "Exit codes should be unique")
        }

        @Test("Window title not found error includes help")
        func windowTitleNotFoundError() {
            let error = CaptureError.windowTitleNotFound("http://example.com", "Safari", "Example Domain, Google")
            let description = error.errorDescription ?? ""

            #expect(description.contains("Window with title containing 'http://example.com' not found"))
            #expect(description.contains("Available windows: Example Domain, Google"))
            #expect(description.contains("try without the protocol"))
        }
    }

    @Suite("JSONResponse Tests")
    struct JSONResponseTests {
        @Test("Encodes success response correctly")
        func successResponse() throws {
            let response = JSONResponse(
                success: true,
                data: ["path": "/tmp/screenshot.png", "size": 1024],
                messages: ["Screenshot captured successfully"],
                debugLogs: ["Starting capture", "Capture complete"]
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(response)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            #expect(json["messages"] as? [String] == ["Screenshot captured successfully"])
            #expect(json["debug_logs"] as? [String] == ["Starting capture", "Capture complete"])
            #expect(json["error"] == nil)

            let dataDict = json["data"] as? [String: Any]
            #expect(dataDict?["path"] as? String == "/tmp/screenshot.png")
            #expect(dataDict?["size"] as? Int == 1024)
        }

        @Test("Encodes error response correctly")
        func errorResponse() throws {
            let errorInfo = ErrorInfo(
                message: "Screen recording permission denied",
                code: .PERMISSION_ERROR_SCREEN_RECORDING,
                details: "Grant permission in System Settings"
            )

            let response = JSONResponse(
                success: false,
                error: errorInfo
            )

            let data = try JSONEncoder().encode(response)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == false)
            #expect(json["data"] == nil)

            let error = json["error"] as? [String: Any]
            #expect(error?["message"] as? String == "Screen recording permission denied")
            #expect(error?["code"] as? String == "PERMISSION_ERROR_SCREEN_RECORDING")
            #expect(error?["details"] as? String == "Grant permission in System Settings")
        }
    }

    @Suite("ErrorCode Tests")
    struct ErrorCodeTests {
        @Test("All error codes have unique string values")
        func errorCodesUnique() {
            let allCodes: [ErrorCode] = [
                .PERMISSION_ERROR_SCREEN_RECORDING,
                .PERMISSION_ERROR_ACCESSIBILITY,
                .APP_NOT_FOUND,
                .AMBIGUOUS_APP_IDENTIFIER,
                .WINDOW_NOT_FOUND,
                .CAPTURE_FAILED,
                .FILE_IO_ERROR,
                .INVALID_ARGUMENT,
                .SIPS_ERROR,
                .INTERNAL_SWIFT_ERROR,
                .UNKNOWN_ERROR,
            ]

            let rawValues = allCodes.map(\.rawValue)
            let uniqueValues = Set(rawValues)

            #expect(rawValues.count == uniqueValues.count, "Error codes should have unique raw values")
        }
    }
}
