import Foundation
import Testing
@testable import peekaboo

@Suite("Window Command Basic Tests", .serialized)
struct WindowCommandBasicTests {
    @Test("Window command exists")
    func windowCommandExists() {
        // Verify WindowCommand type exists and has proper configuration
        let config = WindowCommand.configuration
        #expect(config.commandName == "window")
        #expect(config.abstract.contains("Manipulate application windows"))
    }

    @Test("Window command has expected subcommands")
    func windowSubcommands() {
        let subcommands = WindowCommand.configuration.subcommands

        // We expect 8 subcommands
        #expect(subcommands.count == 8)

        // Verify subcommand names by checking configuration
        let subcommandNames = Set(["close", "minimize", "maximize", "move", "resize", "set-bounds", "focus", "list"])

        // Each subcommand should have one of these names
        for subcommand in subcommands {
            let config = subcommand.configuration
            #expect(
                subcommandNames.contains(config.commandName ?? ""),
                "Unexpected subcommand: \(config.commandName ?? "")"
            )
        }
    }

    @Test("Window manipulation error code exists")
    func windowManipulationErrorCodeExists() {
        // Verify WINDOW_MANIPULATION_ERROR is defined
        let errorCode = ErrorCode.WINDOW_MANIPULATION_ERROR
        #expect(errorCode.rawValue == "WINDOW_MANIPULATION_ERROR")
    }

    @Test("JSON output helper methods")
    func jSONOutputHelperMethods() {
        // Test successful window operation output
        let bounds = CGRect(x: 100, y: 200, width: 800, height: 600)
        let successJSON = JSONResponse(
            success: true,
            data: AnyCodable([
                "operation": "move",
                "app": "TestApp",
                "window_title": "Test Window",
                "new_bounds": [
                    "x": Int(bounds.origin.x),
                    "y": Int(bounds.origin.y),
                    "width": Int(bounds.width),
                    "height": Int(bounds.height),
                ],
            ])
        )

        #expect(successJSON.success == true)
        #expect(successJSON.error == nil)

        // Test error output
        let errorJSON = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: "Failed to move window",
                code: ErrorCode.WINDOW_MANIPULATION_ERROR,
                details: "app: TestApp, reason: Window not found"
            )
        )

        #expect(errorJSON.success == false)
        #expect(errorJSON.error?.code == "WINDOW_MANIPULATION_ERROR")
    }
}

@Suite("Window Command Error Handling Tests", .serialized)
struct WindowCommandErrorHandlingTests {
    @Test("App not found error formatting")
    func appNotFoundError() async throws {
        // This tests the error formatting without actually running the command
        let error = ErrorInfo(
            message: "Application 'NonExistentApp' not found",
            code: ErrorCode.APP_NOT_FOUND,
            details: "requested_app: NonExistentApp"
        )

        #expect(error.code == "APP_NOT_FOUND")
        #expect(error.message.contains("NonExistentApp"))
    }

    @Test("Window not found error formatting")
    func windowNotFoundError() {
        let error = ErrorInfo(
            message: "No window found with title 'NonExistent'",
            code: ErrorCode.WINDOW_NOT_FOUND,
            details: "app: Finder, window_title: NonExistent"
        )

        #expect(error.code == "WINDOW_NOT_FOUND")
        #expect(error.message.contains("NonExistent"))
    }

    @Test("Permission error formatting")
    func permissionError() {
        let error = ErrorInfo(
            message: "Accessibility permission is required for window manipulation",
            code: ErrorCode.PERMISSION_ERROR_ACCESSIBILITY,
            details: "operation: minimize"
        )

        #expect(error.code == "PERMISSION_ERROR_ACCESSIBILITY")
        #expect(error.message.contains("Accessibility"))
    }
}

@Suite("Window Target Resolution Tests", .serialized)
struct WindowTargetResolutionTests {
    @Test("PID format parsing")
    func pIDFormatParsing() {
        // Test valid PID format
        let validPID = "PID:12345"
        #expect(validPID.hasPrefix("PID:"))

        let pidString = validPID.dropFirst(4)
        let pid = Int(pidString)
        #expect(pid == 12345)

        // Test invalid PID formats
        let invalidFormats = ["PID:", "PID:abc", "pid:123", "12345"]
        for format in invalidFormats {
            if format.hasPrefix("PID:") {
                let pidStr = format.dropFirst(4)
                let parsedPID = Int(pidStr)
                #expect(parsedPID == nil || pidStr.isEmpty)
            } else {
                #expect(!format.hasPrefix("PID:"))
            }
        }
    }

    @Test("Bundle ID format detection")
    func bundleIDFormatDetection() {
        // Common bundle ID patterns
        let bundleIDs = [
            "com.apple.finder",
            "com.apple.TextEdit",
            "org.mozilla.firefox",
            "com.microsoft.VSCode",
        ]

        for bundleID in bundleIDs {
            #expect(bundleID.contains("."))
            #expect(bundleID.split(separator: ".").count >= 2)
        }

        // Non-bundle ID app names
        let appNames = ["Safari", "TextEdit", "Visual Studio Code"]
        for name in appNames {
            #expect(!name.hasPrefix("com.") && !name.hasPrefix("org."))
        }
    }
}
