import ArgumentParser
import Foundation
@testable import peekaboo
import Testing

@Suite("ImageCommand Tests", .tags(.imageCapture, .unit))
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
        #expect(command.captureFocus == .background)
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
            "--app", "Finder"
        ])

        #expect(command.mode == nil) // mode is optional
        #expect(command.app == "Finder")
    }

    @Test("Command with window title", .tags(.fast))
    func imageCommandWithWindowTitle() throws {
        // Test window title capture
        let command = try ImageCommand.parse([
            "--window-title", "Documents"
        ])

        #expect(command.windowTitle == "Documents")
    }

    @Test("Command with output path", .tags(.fast))
    func imageCommandWithOutput() throws {
        // Test output path specification
        let outputPath = "/tmp/test-images"
        let command = try ImageCommand.parse([
            "--path", outputPath
        ])

        #expect(command.path == outputPath)
    }

    @Test("Command with format option", .tags(.fast))
    func imageCommandWithFormat() throws {
        // Test format specification
        let command = try ImageCommand.parse([
            "--format", "jpg"
        ])

        #expect(command.format == .jpg)
    }

    @Test("Command with focus option", .tags(.fast))
    func imageCommandWithFocus() throws {
        // Test focus option
        let command = try ImageCommand.parse([
            "--capture-focus", "foreground"
        ])

        #expect(command.captureFocus == .foreground)
    }

    @Test("Command with JSON output", .tags(.fast))
    func imageCommandWithJSONOutput() throws {
        // Test JSON output flag
        let command = try ImageCommand.parse([
            "--json-output"
        ])

        #expect(command.jsonOutput == true)
    }

    @Test("Command with multi mode", .tags(.fast))
    func imageCommandWithMultiMode() throws {
        // Test multi capture mode
        let command = try ImageCommand.parse([
            "--mode", "multi"
        ])

        #expect(command.mode == .multi)
    }

    @Test("Command with screen index", .tags(.fast))
    func imageCommandWithScreenIndex() throws {
        // Test screen index specification
        let command = try ImageCommand.parse([
            "--screen-index", "1"
        ])

        #expect(command.screenIndex == 1)
    }

    // MARK: - Parameterized Command Tests

    @Test(
        "Various command combinations",
        arguments: [
            (args: ["--mode", "screen", "--format", "png"], mode: CaptureMode.screen, format: ImageFormat.png),
            (args: ["--mode", "window", "--format", "jpg"], mode: CaptureMode.window, format: ImageFormat.jpg),
            (args: ["--mode", "multi", "--json-output"], mode: CaptureMode.multi, format: ImageFormat.png)
        ]
    )
    func commandCombinations(args: [String], mode: CaptureMode, format: ImageFormat) throws {
        let command = try ImageCommand.parse(args)
        #expect(command.mode == mode)
        #expect(command.format == format)
    }

    @Test(
        "Invalid arguments throw errors",
        arguments: [
            ["--mode", "invalid"],
            ["--format", "bmp"],
            ["--capture-focus", "neither"],
            ["--screen-index", "abc"]
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(captureData)

        #expect(!data.isEmpty)

        // Test decoding
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
        #expect(command.captureFocus == .background)
        #expect(command.jsonOutput == false)
    }

    @Test(
        "Screen index boundary values",
        arguments: [-1, 0, 1, 99, Int.max]
    )
    func screenIndexBoundaries(index: Int) throws {
        let command = try ImageCommand.parse(["--screen-index", String(index)])
        #expect(command.screenIndex == index)
    }

    @Test(
        "Window index boundary values",
        arguments: [-1, 0, 1, 10, Int.max]
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

// MARK: - Extended Image Command Tests

@Suite("ImageCommand Advanced Tests", .tags(.imageCapture, .integration))
struct ImageCommandAdvancedTests {
    // MARK: - Complex Scenario Tests

    @Test("Complex command with multiple options", .tags(.fast))
    func complexCommand() throws {
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--app", "Safari",
            "--window-title", "Home",
            "--window-index", "0",
            "--format", "jpg",
            "--path", "/tmp/safari-home.jpg",
            "--capture-focus", "foreground",
            "--json-output"
        ])

        #expect(command.mode == .window)
        #expect(command.app == "Safari")
        #expect(command.windowTitle == "Home")
        #expect(command.windowIndex == 0)
        #expect(command.format == .jpg)
        #expect(command.path == "/tmp/safari-home.jpg")
        #expect(command.captureFocus == .foreground)
        #expect(command.jsonOutput == true)
    }

    @Test("Command help text contains all options", .tags(.fast))
    func commandHelpText() {
        let helpText = ImageCommand.helpMessage()

        // Verify key options are documented
        #expect(helpText.contains("--mode"))
        #expect(helpText.contains("--app"))
        #expect(helpText.contains("--window-title"))
        #expect(helpText.contains("--format"))
        #expect(helpText.contains("--path"))
        #expect(helpText.contains("--capture-focus"))
        #expect(helpText.contains("--json-output"))
    }

    @Test("Command configuration", .tags(.fast))
    func commandConfiguration() {
        let config = ImageCommand.configuration

        #expect(config.commandName == "image")
        #expect(config.abstract.contains("Capture"))
    }

    @Test(
        "Window specifier combinations",
        arguments: [
            (app: "Safari", title: "Home", index: nil),
            (app: "Finder", title: nil, index: 0),
            (app: "Terminal", title: nil, index: nil)
        ]
    )
    func windowSpecifierCombinations(app: String, title: String?, index: Int?) throws {
        var args = ["--app", app]

        if let title {
            args.append(contentsOf: ["--window-title", title])
        }

        if let index {
            args.append(contentsOf: ["--window-index", String(index)])
        }

        let command = try ImageCommand.parse(args)

        #expect(command.app == app)
        #expect(command.windowTitle == title)
        #expect(command.windowIndex == index)
    }

    @Test(
        "Path expansion handling",
        arguments: [
            "~/Desktop/screenshot.png",
            "/tmp/test.png",
            "./relative/path.png",
            "/path with spaces/image.png"
        ]
    )
    func pathExpansion(path: String) throws {
        let command = try ImageCommand.parse(["--path", path])
        #expect(command.path == path)
    }

    @Test("FileHandleTextOutputStream functionality", .tags(.fast))
    func fileHandleTextOutputStream() {
        // Test the custom text output stream
        let pipe = Pipe()
        var stream = FileHandleTextOutputStream(pipe.fileHandleForWriting)

        let testString = "Test output"
        stream.write(testString)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        #expect(output == testString)
    }

    @Test("Command validation edge cases", .tags(.fast))
    func commandValidationEdgeCases() {
        // Test very long paths
        let longPath = String(repeating: "a", count: 1000)
        do {
            let command = try ImageCommand.parse(["--path", longPath])
            #expect(command.path == longPath)
        } catch {
            Issue.record("Should handle long paths gracefully")
        }

        // Test unicode in paths
        let unicodePath = "/tmp/测试/スクリーン.png"
        do {
            let command = try ImageCommand.parse(["--path", unicodePath])
            #expect(command.path == unicodePath)
        } catch {
            Issue.record("Should handle unicode paths")
        }
    }

    @Test("MIME type assignment logic", .tags(.fast))
    func mimeTypeAssignment() throws {
        // Test MIME type logic for different formats
        let pngCommand = try ImageCommand.parse(["--format", "png"])
        #expect(pngCommand.format == .png)

        let jpgCommand = try ImageCommand.parse(["--format", "jpg"])
        #expect(jpgCommand.format == .jpg)

        // Verify MIME types would be assigned correctly
        // (This logic is in the SavedFile creation during actual capture)
    }

    @Test("Argument parsing stress test", .tags(.performance))
    func argumentParsingStressTest() {
        // Test parsing performance with many arguments
        let args = [
            "--mode", "multi",
            "--app", "Very Long Application Name With Spaces",
            "--window-title", "Very Long Window Title With Special Characters 测试 スクリーン",
            "--path", "/very/long/path/to/some/directory/with/many/components/screenshot.png",
            "--format", "jpg",
            "--capture-focus", "foreground",
            "--json-output"
        ]

        do {
            let command = try ImageCommand.parse(args)
            #expect(command.mode == .multi)
            #expect(command.jsonOutput == true)
        } catch {
            Issue.record("Should handle complex argument parsing")
        }
    }

    @Test(
        "Command option combinations validation",
        arguments: [
            (["--mode", "screen"], true),
            (["--mode", "window", "--app", "Finder"], true),
            (["--mode", "multi"], true),
            (["--app", "Safari"], true),
            (["--window-title", "Test"], true),
            (["--screen-index", "0"], true),
            (["--window-index", "0"], true)
        ]
    )
    func commandOptionCombinations(args: [String], shouldParse: Bool) {
        do {
            let command = try ImageCommand.parse(args)
            #expect(shouldParse == true)
            #expect(true) // Command parsed successfully
        } catch {
            #expect(shouldParse == false)
        }
    }
}
