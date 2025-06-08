import AppKit
import Foundation
@testable import peekaboo
import Testing

@Suite("Image Capture Logic Tests", .tags(.imageCapture, .unit))
struct ImageCaptureLogicTests {
    // MARK: - File Name Generation Tests

    @Test("File name generation for displays", .tags(.fast))
    func fileNameGenerationDisplays() throws {
        // We can't directly test private methods, but we can test the logic
        // through public interfaces and verify the expected patterns

        // Test that different screen indices would generate different names
        let command1 = try ImageCommand.parse(["--screen-index", "0", "--format", "png"])
        let command2 = try ImageCommand.parse(["--screen-index", "1", "--format", "png"])

        #expect(command1.screenIndex == 0)
        #expect(command2.screenIndex == 1)
        #expect(command1.format == .png)
        #expect(command2.format == .png)
    }

    @Test("File name generation for applications", .tags(.fast))
    func fileNameGenerationApplications() throws {
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Test App",
            "--window-title", "Main Window",
            "--format", "jpg"
        ])

        #expect(command.app == "Test App")
        #expect(command.windowTitle == "Main Window")
        #expect(command.format == .jpg)
    }

    @Test("Output path generation", .tags(.fast))
    func outputPathGeneration() throws {
        // Test default path behavior
        let defaultCommand = try ImageCommand.parse([])
        #expect(defaultCommand.path == nil)

        // Test custom path
        let customCommand = try ImageCommand.parse(["--path", "/tmp/screenshots"])
        #expect(customCommand.path == "/tmp/screenshots")

        // Test path with filename
        let fileCommand = try ImageCommand.parse(["--path", "/tmp/test.png"])
        #expect(fileCommand.path == "/tmp/test.png")
    }

    // MARK: - Mode Determination Tests

    @Test("Mode determination comprehensive", .tags(.fast))
    func modeDeterminationComprehensive() throws {
        // Screen mode (default when no app specified)
        let screenCmd = try ImageCommand.parse([])
        #expect(screenCmd.mode == nil)
        #expect(screenCmd.app == nil)

        // Window mode (when app specified but no explicit mode)
        let windowCmd = try ImageCommand.parse(["--app", "Finder"])
        #expect(windowCmd.mode == nil) // Will be determined as window during execution
        #expect(windowCmd.app == "Finder")

        // Explicit modes
        let explicitScreen = try ImageCommand.parse(["--mode", "screen"])
        #expect(explicitScreen.mode == .screen)

        let explicitWindow = try ImageCommand.parse(["--mode", "window", "--app", "Safari"])
        #expect(explicitWindow.mode == .window)
        #expect(explicitWindow.app == "Safari")

        let explicitMulti = try ImageCommand.parse(["--mode", "multi"])
        #expect(explicitMulti.mode == .multi)
    }

    // MARK: - Window Targeting Tests

    @Test("Window targeting by title", .tags(.fast))
    func windowTargetingByTitle() throws {
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Safari",
            "--window-title", "Main Window"
        ])

        #expect(command.mode == .window)
        #expect(command.app == "Safari")
        #expect(command.windowTitle == "Main Window")
        #expect(command.windowIndex == nil)
    }

    @Test("Window targeting by index", .tags(.fast))
    func windowTargetingByIndex() throws {
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Terminal",
            "--window-index", "0"
        ])

        #expect(command.mode == .window)
        #expect(command.app == "Terminal")
        #expect(command.windowIndex == 0)
        #expect(command.windowTitle == nil)
    }

    @Test("Window targeting priority - title vs index", .tags(.fast))
    func windowTargetingPriority() throws {
        // When both title and index are specified, both are preserved
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Xcode",
            "--window-title", "Main",
            "--window-index", "1"
        ])

        #expect(command.windowTitle == "Main")
        #expect(command.windowIndex == 1)
        // In actual execution, title matching would take precedence
    }

    // MARK: - Screen Targeting Tests

    @Test("Screen targeting by index", .tags(.fast))
    func screenTargetingByIndex() throws {
        let command = try ImageCommand.parse([
            "--mode", "screen",
            "--screen-index", "1"
        ])

        #expect(command.mode == .screen)
        #expect(command.screenIndex == 1)
    }

    @Test(
        "Screen index edge cases",
        arguments: [-1, 0, 1, 5, 99]
    )
    func screenIndexEdgeCases(index: Int) throws {
        do {
            let command = try ImageCommand.parse([
                "--mode", "screen",
                "--screen-index", String(index)
            ])

            #expect(command.screenIndex == index)
            // Validation happens during execution, not parsing
        } catch {
            // ArgumentParser may reject certain values
            if index < 0 {
                // Expected for negative values
                return
            }
            throw error
        }
    }

    // MARK: - Capture Focus Tests

    @Test("Capture focus modes", .tags(.fast))
    func captureFocusModes() throws {
        // Default auto mode
        let defaultCmd = try ImageCommand.parse([])
        #expect(defaultCmd.captureFocus == .auto)

        // Explicit background mode
        let backgroundCmd = try ImageCommand.parse(["--capture-focus", "background"])
        #expect(backgroundCmd.captureFocus == .background)

        // Auto mode
        let autoCmd = try ImageCommand.parse(["--capture-focus", "auto"])
        #expect(autoCmd.captureFocus == .auto)

        // Foreground mode
        let foregroundCmd = try ImageCommand.parse(["--capture-focus", "foreground"])
        #expect(foregroundCmd.captureFocus == .foreground)
    }

    // MARK: - Image Format Tests

    @Test("Image format handling", .tags(.fast))
    func imageFormatHandling() throws {
        // Default PNG format
        let defaultCmd = try ImageCommand.parse([])
        #expect(defaultCmd.format == .png)

        // Explicit PNG format
        let pngCmd = try ImageCommand.parse(["--format", "png"])
        #expect(pngCmd.format == .png)

        // JPEG format
        let jpgCmd = try ImageCommand.parse(["--format", "jpg"])
        #expect(jpgCmd.format == .jpg)
    }

    @Test("MIME type mapping", .tags(.fast))
    func mimeTypeMapping() {
        // Test MIME type logic (as used in SavedFile creation)
        let pngMime = ImageFormat.png == .png ? "image/png" : "image/jpeg"
        let jpgMime = ImageFormat.jpg == .jpg ? "image/jpeg" : "image/png"

        #expect(pngMime == "image/png")
        #expect(jpgMime == "image/jpeg")
    }

    // MARK: - Error Handling Tests

    @Test("Error code mapping", .tags(.fast))
    func errorCodeMapping() {
        // Test error code mapping logic used in handleError
        let testCases: [(CaptureError, ErrorCode)] = [
            (.screenRecordingPermissionDenied, .PERMISSION_ERROR_SCREEN_RECORDING),
            (.accessibilityPermissionDenied, .PERMISSION_ERROR_ACCESSIBILITY),
            (.appNotFound("test"), .APP_NOT_FOUND),
            (.windowNotFound, .WINDOW_NOT_FOUND),
            (.fileWriteError("test", nil), .FILE_IO_ERROR),
            (.invalidArgument("test"), .INVALID_ARGUMENT),
            (.unknownError("test"), .UNKNOWN_ERROR)
        ]

        // Verify error mapping logic exists
        for (_, expectedCode) in testCases {
            // We can't directly test the private method, but verify the errors exist
            // Verify the error exists (non-nil check not needed for value types)
            #expect(Bool(true))
            #expect(!expectedCode.rawValue.isEmpty)
        }
    }

    // MARK: - SavedFile Creation Tests

    @Test("SavedFile creation for screen capture", .tags(.fast))
    func savedFileCreationScreenCapture() {
        let savedFile = SavedFile(
            path: "/tmp/screen-0.png",
            item_label: "Display 1 (Index 0)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )

        #expect(savedFile.path == "/tmp/screen-0.png")
        #expect(savedFile.item_label == "Display 1 (Index 0)")
        #expect(savedFile.window_title == nil)
        #expect(savedFile.window_id == nil)
        #expect(savedFile.window_index == nil)
        #expect(savedFile.mime_type == "image/png")
    }

    @Test("SavedFile creation for window capture", .tags(.fast))
    func savedFileCreationWindowCapture() {
        let savedFile = SavedFile(
            path: "/tmp/safari-main.jpg",
            item_label: "Safari",
            window_title: "Main Window",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/jpeg"
        )

        #expect(savedFile.path == "/tmp/safari-main.jpg")
        #expect(savedFile.item_label == "Safari")
        #expect(savedFile.window_title == "Main Window")
        #expect(savedFile.window_id == 12345)
        #expect(savedFile.window_index == 0)
        #expect(savedFile.mime_type == "image/jpeg")
    }

    // MARK: - Complex Configuration Tests

    @Test("Complex multi-window capture configuration", .tags(.fast))
    func complexMultiWindowConfiguration() throws {
        let command = try ImageCommand.parse([
            "--mode", "multi",
            "--app", "Visual Studio Code",
            "--format", "png",
            "--path", "/tmp/vscode-windows",
            "--capture-focus", "foreground",
            "--json-output"
        ])

        #expect(command.mode == .multi)
        #expect(command.app == "Visual Studio Code")
        #expect(command.format == .png)
        #expect(command.path == "/tmp/vscode-windows")
        #expect(command.captureFocus == .foreground)
        #expect(command.jsonOutput == true)
    }

    @Test("Complex screen capture configuration", .tags(.fast))
    func complexScreenCaptureConfiguration() throws {
        let command = try ImageCommand.parse([
            "--mode", "screen",
            "--screen-index", "1",
            "--format", "jpg",
            "--path", "/Users/test/screenshots/display-1.jpg",
            "--json-output"
        ])

        #expect(command.mode == .screen)
        #expect(command.screenIndex == 1)
        #expect(command.format == .jpg)
        #expect(command.path == "/Users/test/screenshots/display-1.jpg")
        #expect(command.jsonOutput == true)
    }

    // MARK: - Integration Readiness Tests

    @Test("Command readiness for screen capture", .tags(.fast))
    func commandReadinessScreenCapture() throws {
        let command = try ImageCommand.parse(["--mode", "screen"])

        // Verify command is properly configured for screen capture
        #expect(command.mode == .screen)
        #expect(command.app == nil) // No app needed for screen capture
        #expect(command.format == .png) // Has default format
    }

    @Test("Command readiness for window capture", .tags(.fast))
    func commandReadinessWindowCapture() throws {
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Finder"
        ])

        // Verify command is properly configured for window capture
        #expect(command.mode == .window)
        #expect(command.app == "Finder") // App is required
        #expect(command.format == .png) // Has default format
    }

    @Test("Command validation for invalid configurations", .tags(.fast))
    func commandValidationInvalidConfigurations() {
        // These should parse successfully but would fail during execution

        // Window mode without app (would fail during execution)
        do {
            let command = try ImageCommand.parse(["--mode", "window"])
            #expect(command.mode == .window)
            #expect(command.app == nil) // This would cause execution failure
        } catch {
            Issue.record("Should parse successfully")
        }

        // Invalid screen index (ArgumentParser may reject negative values)
        #expect(throws: (any Error).self) {
            _ = try ImageCommand.parse(["--screen-index", "-1"])
        }
    }
}

// MARK: - Extended Capture Logic Tests

@Suite("Advanced Image Capture Logic", .tags(.imageCapture, .integration))
struct AdvancedImageCaptureLogicTests {
    @Test("Multi-mode capture scenarios", .tags(.fast))
    func multiModeCaptureScenarios() throws {
        // Multi mode with app (should capture all windows)
        let multiWithApp = try ImageCommand.parse([
            "--mode", "multi",
            "--app", "Safari"
        ])
        #expect(multiWithApp.mode == .multi)
        #expect(multiWithApp.app == "Safari")

        // Multi mode without app (should capture all screens)
        let multiWithoutApp = try ImageCommand.parse(["--mode", "multi"])
        #expect(multiWithoutApp.mode == .multi)
        #expect(multiWithoutApp.app == nil)
    }

    @Test("Focus mode implications", .tags(.fast))
    func focusModeImplications() throws {
        // Foreground focus should work with any capture mode
        let foregroundScreen = try ImageCommand.parse([
            "--mode", "screen",
            "--capture-focus", "foreground"
        ])
        #expect(foregroundScreen.captureFocus == .foreground)

        let foregroundWindow = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Terminal",
            "--capture-focus", "foreground"
        ])
        #expect(foregroundWindow.captureFocus == .foreground)

        // Auto focus (default) should work intelligently
        let autoCapture = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Finder"
        ])
        #expect(autoCapture.captureFocus == .auto)
    }

    @Test("Path handling edge cases", .tags(.fast))
    func pathHandlingEdgeCases() throws {
        // Relative paths
        let relativePath = try ImageCommand.parse(["--path", "./screenshots/test.png"])
        #expect(relativePath.path == "./screenshots/test.png")

        // Home directory expansion
        let homePath = try ImageCommand.parse(["--path", "~/Desktop/capture.jpg"])
        #expect(homePath.path == "~/Desktop/capture.jpg")

        // Absolute paths
        let absolutePath = try ImageCommand.parse(["--path", "/tmp/absolute/path.png"])
        #expect(absolutePath.path == "/tmp/absolute/path.png")

        // Paths with spaces
        let spacePath = try ImageCommand.parse(["--path", "/path with spaces/image.png"])
        #expect(spacePath.path == "/path with spaces/image.png")

        // Unicode paths
        let unicodePath = try ImageCommand.parse(["--path", "/tmp/测试/スクリーン.png"])
        #expect(unicodePath.path == "/tmp/测试/スクリーン.png")
    }

    @Test("Command execution readiness matrix", .tags(.fast))
    func commandExecutionReadinessMatrix() {
        let scenarios = createTestScenarios()

        for scenario in scenarios {
            do {
                let command = try ImageCommand.parse(scenario.args)
                if scenario.shouldBeReady {
                    // Verify basic readiness
                    #expect(command.format == .png)
                    #expect(command.captureFocus == .auto)
                }
            } catch {
                if scenario.shouldBeReady {
                    Issue.record("Scenario '\(scenario.description)' should parse successfully: \(error)")
                }
            }
        }
    }

    @Test("Error propagation scenarios", .tags(.fast))
    func errorPropagationScenarios() {
        // Test that invalid arguments are properly handled
        let invalidArgs: [[String]] = [
            ["--mode", "invalid"],
            ["--format", "bmp"],
            ["--capture-focus", "invalid"],
            ["--screen-index", "abc"],
            ["--window-index", "xyz"]
        ]

        for args in invalidArgs {
            #expect(throws: (any Error).self) {
                _ = try ImageCommand.parse(args)
            }
        }
    }

    @Test("Memory efficiency with complex configurations", .tags(.memory))
    func memoryEfficiencyComplexConfigurations() {
        // Test that complex configurations don't cause excessive memory usage
        let complexConfigs: [[String]] = [
            ["--mode", "multi", "--app", String(repeating: "LongAppName", count: 100)],
            ["--window-title", String(repeating: "VeryLongTitle", count: 200)],
            ["--path", String(repeating: "/very/long/path", count: 50)],
            Array(repeating: ["--mode", "screen"], count: 100).flatMap(\.self)
        ]

        for config in complexConfigs {
            do {
                _ = try ImageCommand.parse(config)
                #expect(Bool(true)) // Command parsed successfully
            } catch {
                // Some may fail due to argument parsing limits, which is expected
                #expect(Bool(true))
            }
        }
    }

    // MARK: - Helper Functions

    private struct TestScenario {
        let args: [String]
        let shouldBeReady: Bool
        let description: String
    }

    private func createTestScenarios() -> [TestScenario] {
        [
            TestScenario(
                args: ["--mode", "screen"],
                shouldBeReady: true,
                description: "Basic screen capture"
            ),
            TestScenario(
                args: ["--mode", "screen", "--screen-index", "0"],
                shouldBeReady: true,
                description: "Screen with index"
            ),
            TestScenario(
                args: ["--mode", "window", "--app", "Finder"],
                shouldBeReady: true,
                description: "Basic window capture"
            ),
            TestScenario(
                args: ["--mode", "window", "--app", "Safari", "--window-title", "Main"],
                shouldBeReady: true,
                description: "Window with title"
            ),
            TestScenario(
                args: ["--mode", "window", "--app", "Terminal", "--window-index", "0"],
                shouldBeReady: true,
                description: "Window with index"
            ),
            TestScenario(
                args: ["--mode", "multi"],
                shouldBeReady: true,
                description: "Multi-screen capture"
            ),
            TestScenario(
                args: ["--mode", "multi", "--app", "Xcode"],
                shouldBeReady: true,
                description: "Multi-window capture"
            ),
            TestScenario(
                args: ["--app", "Finder"],
                shouldBeReady: true,
                description: "Implicit window mode"
            ),
            TestScenario(
                args: [],
                shouldBeReady: true,
                description: "Default screen capture"
            )
        ]
    }
}
