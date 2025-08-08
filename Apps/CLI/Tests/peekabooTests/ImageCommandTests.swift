// swiftlint:disable file_length
import ArgumentParser
import Foundation
import PeekabooCore
import Testing
@testable import peekaboo

@Suite("ImageCommand Tests", .serialized, .tags(.imageCapture, .unit))
struct ImageCommandTests {
    // MARK: - Test Data & Helpers

    private static let validFormats: [ImageFormat] = [.png, .jpg]
    private static let validCaptureModes: [CaptureMode] = [.screen, .window, .multi]
    private static let validCaptureFocus: [CaptureFocus] = [.background, .foreground]

    private static func createTestCommand(_ args: [String] = []) throws -> ImageCommand {
        try ImageCommand.parse(args)
    }

    // MARK: - Command Parsing Tests

    @Test("Basic command parsing with defaults", .tags(.fast))
    func imageCommandParsing() throws {
        // Test basic command parsing
        let command = try ImageCommand.parse([])

        // Verify defaults
        #expect(command.mode == nil)
        #expect(command.format == .png)
        #expect(command.path == nil)
        #expect(command.app == nil)
        #expect(command.captureFocus == .auto)
        #expect(command.jsonOutput == false)
    }

    @Test("Command with screen mode", .tags(.fast))
    func imageCommandWithScreenMode() throws {
        // Test screen capture mode
        let command = try ImageCommand.parse(["--mode", "screen"])

        #expect(command.mode == .screen)
    }

    @Test("Command with app specifier", .tags(.fast))
    func imageCommandWithAppSpecifier() throws {
        // Test app-specific capture
        let command = try ImageCommand.parse([
            "--app", "Finder",
        ])

        #expect(command.mode == nil) // mode is optional
        #expect(command.app == "Finder")
    }

    @Test("Command with PID specifier", .tags(.fast))
    func imageCommandWithPIDSpecifier() throws {
        // Test PID-specific capture
        let command = try ImageCommand.parse([
            "--app", "PID:1234",
        ])

        #expect(command.mode == nil) // mode is optional
        #expect(command.app == "PID:1234")
    }

    @Test("Command with window title", .tags(.fast))
    func imageCommandWithWindowTitle() throws {
        // Test window title capture
        let command = try ImageCommand.parse([
            "--window-title", "Documents",
        ])

        #expect(command.windowTitle == "Documents")
    }

    @Test("Command with output path", .tags(.fast))
    func imageCommandWithOutput() throws {
        // Test output path specification
        let outputPath = "/tmp/test-images"
        let command = try ImageCommand.parse([
            "--path", outputPath,
        ])

        #expect(command.path == outputPath)
    }

    @Test("Command with format option", .tags(.fast))
    func imageCommandWithFormat() throws {
        // Test format specification
        let command = try ImageCommand.parse([
            "--format", "jpg",
        ])

        #expect(command.format == .jpg)
    }

    @Test("Command with focus option", .tags(.fast))
    func imageCommandWithFocus() throws {
        // Test focus option
        let command = try ImageCommand.parse([
            "--capture-focus", "foreground",
        ])

        #expect(command.captureFocus == .foreground)
    }

    @Test("Command with JSON output", .tags(.fast))
    func imageCommandWithJSONOutput() throws {
        // Test JSON output flag
        let command = try ImageCommand.parse([
            "--json-output",
        ])

        #expect(command.jsonOutput == true)
    }

    @Test("Command with multi mode", .tags(.fast))
    func imageCommandWithMultiMode() throws {
        // Test multi capture mode
        let command = try ImageCommand.parse([
            "--mode", "multi",
        ])

        #expect(command.mode == .multi)
    }

    @Test("Command with screen index", .tags(.fast))
    func imageCommandWithScreenIndex() throws {
        // Test screen index specification
        let command = try ImageCommand.parse([
            "--screen-index", "1",
        ])

        #expect(command.screenIndex == 1)
    }

    @Test("Command with analyze option", .tags(.fast))
    func imageCommandWithAnalyze() throws {
        // Test analyze option parsing
        let command = try ImageCommand.parse([
            "--analyze", "What is shown in this image?",
        ])

        #expect(command.analyze == "What is shown in this image?")
    }

    @Test("Command with analyze and app", .tags(.fast))
    func imageCommandWithAnalyzeAndApp() throws {
        // Test analyze with app specification
        let command = try ImageCommand.parse([
            "--app", "Safari",
            "--analyze", "Summarize this webpage",
        ])

        #expect(command.app == "Safari")
        #expect(command.analyze == "Summarize this webpage")
    }

    @Test("Command with analyze and mode", .tags(.fast))
    func imageCommandWithAnalyzeAndMode() throws {
        // Test analyze with different capture modes
        let command = try ImageCommand.parse([
            "--mode", "frontmost",
            "--analyze", "What errors are shown?",
        ])

        #expect(command.mode == .frontmost)
        #expect(command.analyze == "What errors are shown?")
    }

    @Test("Command with analyze and JSON output", .tags(.fast))
    func imageCommandWithAnalyzeAndJSON() throws {
        // Test analyze with JSON output
        let command = try ImageCommand.parse([
            "--analyze", "Describe the UI",
            "--json-output",
        ])

        #expect(command.analyze == "Describe the UI")
        #expect(command.jsonOutput == true)
    }

    // MARK: - Parameterized Command Tests

    @Test(
        "Various command combinations",
        arguments: [
            (args: ["--mode", "screen", "--format", "png"], mode: CaptureMode.screen, format: ImageFormat.png),
            (args: ["--mode", "window", "--format", "jpg"], mode: CaptureMode.window, format: ImageFormat.jpg),
            (args: ["--mode", "multi", "--json-output"], mode: CaptureMode.multi, format: ImageFormat.png),
        ]
    )
    func commandCombinations(args: [String], mode: CaptureMode, format: ImageFormat) throws {
        let command = try ImageCommand.parse(args)
        #expect(command.mode == mode)
        #expect(command.format == format)
    }

    @Test(
        "Analyze option with different modes",
        arguments: [
            (
                args: ["--mode", "screen", "--analyze", "What is on screen?"],
                mode: CaptureMode.screen,
                prompt: "What is on screen?"
            ),
            (
                args: ["--mode", "window", "--analyze", "Describe this window"],
                mode: CaptureMode.window,
                prompt: "Describe this window"
            ),
            (
                args: ["--mode", "multi", "--analyze", "Compare windows"],
                mode: CaptureMode.multi,
                prompt: "Compare windows"
            ),
            (
                args: ["--mode", "frontmost", "--analyze", "What app is this?"],
                mode: CaptureMode.frontmost,
                prompt: "What app is this?"
            ),
        ]
    )
    func analyzeWithDifferentModes(args: [String], mode: CaptureMode, prompt: String) throws {
        let command = try ImageCommand.parse(args)
        #expect(command.mode == mode)
        #expect(command.analyze == prompt)
    }

    @Test(
        "Invalid arguments throw errors",
        arguments: [
            ["--mode", "invalid"],
            ["--format", "bmp"],
            ["--capture-focus", "neither"],
            ["--screen-index", "abc"],
        ]
    )
    func invalidArguments(args: [String]) {
        #expect(throws: (any Error).self) {
            _ = try ImageCommand.parse(args)
        }
    }

    // MARK: - Model Tests

    @Test("SavedFile model creation", .tags(.fast))
    func savedFileModel() {
        let savedFile = SavedFile(
            path: "/tmp/screenshot.png",
            item_label: "Screen 1",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )

        #expect(savedFile.path == "/tmp/screenshot.png")
        #expect(savedFile.item_label == "Screen 1")
        #expect(savedFile.mime_type == "image/png")
    }

    @Test("ImageCaptureData encoding", .tags(.fast))
    func imageCaptureDataEncoding() throws {
        let savedFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Test",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )

        let captureData = ImageCaptureData(saved_files: [savedFile])

        // Test JSON encoding
        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed
        let data = try encoder.encode(captureData)

        #expect(!data.isEmpty)

        // Test decoding
        let decoder = JSONDecoder()
        // Properties are already in snake_case, no conversion needed
        let decoded = try decoder.decode(ImageCaptureData.self, from: data)

        #expect(decoded.saved_files.count == 1)
        #expect(decoded.saved_files[0].path == "/tmp/test.png")
    }

    // MARK: - Enum Raw Value Tests

    @Test("CaptureMode raw values", .tags(.fast))
    func captureModeRawValues() {
        #expect(CaptureMode.screen.rawValue == "screen")
        #expect(CaptureMode.window.rawValue == "window")
        #expect(CaptureMode.multi.rawValue == "multi")
    }

    @Test("ImageFormat raw values", .tags(.fast))
    func imageFormatRawValues() {
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.jpg.rawValue == "jpg")
    }

    @Test("CaptureFocus raw values", .tags(.fast))
    func captureFocusRawValues() {
        #expect(CaptureFocus.background.rawValue == "background")
        #expect(CaptureFocus.foreground.rawValue == "foreground")
    }

    // MARK: - Mode Determination & Logic Tests

    @Test("Mode determination logic", .tags(.fast))
    func modeDeterminationLogic() throws {
        // No mode, no app -> should default to screen
        let screenCommand = try ImageCommand.parse([])
        #expect(screenCommand.mode == nil)
        #expect(screenCommand.app == nil)

        // No mode, with app -> should infer window mode in actual execution
        let windowCommand = try ImageCommand.parse(["--app", "Finder"])
        #expect(windowCommand.mode == nil)
        #expect(windowCommand.app == "Finder")

        // Explicit mode should be preserved
        let explicitCommand = try ImageCommand.parse(["--mode", "multi"])
        #expect(explicitCommand.mode == .multi)
    }

    @Test("Default values verification", .tags(.fast))
    func defaultValues() throws {
        let command = try ImageCommand.parse([])

        #expect(command.mode == nil)
        #expect(command.format == .png)
        #expect(command.path == nil)
        #expect(command.app == nil)
        #expect(command.windowTitle == nil)
        #expect(command.windowIndex == nil)
        #expect(command.screenIndex == nil)
        #expect(command.captureFocus == .auto)
        #expect(command.jsonOutput == false)
        #expect(command.analyze == nil)
    }

    @Test(
        "Screen index boundary values",
        arguments: [0, 1, 99, 9999]
    )
    func screenIndexBoundaries(index: Int) throws {
        let command = try ImageCommand.parse(["--screen-index", String(index)])
        #expect(command.screenIndex == index)
    }

    @Test(
        "Window index boundary values",
        arguments: [0, 1, 10, 9999]
    )
    func windowIndexBoundaries(index: Int) throws {
        let command = try ImageCommand.parse(["--window-index", String(index)])
        #expect(command.windowIndex == index)
    }

    @Test("Error handling for invalid combinations", .tags(.fast))
    func invalidCombinations() {
        // Window capture without app should fail in execution
        // This tests the parsing, execution would fail later
        do {
            let command = try ImageCommand.parse(["--mode", "window"])
            #expect(command.mode == .window)
            #expect(command.app == nil) // This would cause execution error
        } catch {
            Issue.record("Parsing should succeed even with invalid combinations")
        }
    }
}
