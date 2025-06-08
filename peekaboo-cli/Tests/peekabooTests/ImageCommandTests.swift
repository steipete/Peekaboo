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
        #expect(command.captureFocus == .background)
        #expect(command.jsonOutput == false)
    }

    @Test(
        "Screen index boundary values",
        arguments: [-1, 0, 1, 99, 9999]
    )
    func screenIndexBoundaries(index: Int) throws {
        let command = try ImageCommand.parse(["--screen-index", String(index)])
        #expect(command.screenIndex == index)
    }

    @Test(
        "Window index boundary values",
        arguments: [-1, 0, 1, 10, 9999]
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

// MARK: - Path Handling Tests

@Suite("ImageCommand Path Handling Tests", .tags(.imageCapture, .unit))
struct ImageCommandPathHandlingTests {
    // MARK: - Helper Methods
    
    private func createTestImageCommand(path: String?, screenIndex: Int? = nil) -> ImageCommand {
        var command = ImageCommand()
        command.path = path
        command.screenIndex = screenIndex
        command.format = .png
        return command
    }
    
    // MARK: - Path Detection Tests
    
    @Test("File vs directory path detection", .tags(.fast))
    func pathDetection() {
        
        // Test file-like paths (have extension, no trailing slash)
        let filePaths = [
            "/tmp/screenshot.png",
            "/home/user/image.jpg",
            "/path/with spaces/file.png",
            "./relative/file.png",
            "simple.png"
        ]
        
        // Test directory-like paths (no extension or trailing slash)
        let directoryPaths = [
            "/tmp/",
            "/home/user/screenshots",
            "/path/with spaces/",
            "simple-dir"
        ]
        
        // File paths should be detected correctly
        for filePath in filePaths {
            let isLikelyFile = filePath.contains(".") && !filePath.hasSuffix("/")
            #expect(isLikelyFile == true, "Path '\(filePath)' should be detected as file")
        }
        
        // Directory paths should be detected correctly
        for dirPath in directoryPaths {
            let isLikelyFile = dirPath.contains(".") && !dirPath.hasSuffix("/")
            #expect(isLikelyFile == false, "Path '\(dirPath)' should be detected as directory")
        }
    }
    
    @Test("Single screen file path handling", .tags(.fast))
    func singleScreenFilePath() {
        let command = createTestImageCommand(path: "/tmp/my-screenshot.png", screenIndex: 0)
        
        // For single screen, should use exact path
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: "/tmp/my-screenshot.png", fileName: fileName)
        
        #expect(result == "/tmp/my-screenshot.png")
    }
    
    @Test("Multiple screens file path handling", .tags(.fast))
    func multipleScreensFilePath() {
        let command = createTestImageCommand(path: "/tmp/screenshot.png", screenIndex: nil)
        
        // For multiple screens, should append screen info
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: "/tmp/screenshot.png", fileName: fileName)
        
        #expect(result == "/tmp/screenshot_1_20250608_120000.png")
    }
    
    @Test("Directory path handling", .tags(.fast))
    func directoryPathHandling() {
        let command = createTestImageCommand(path: "/tmp/screenshots", screenIndex: nil)
        
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: "/tmp/screenshots", fileName: fileName)
        
        #expect(result == "/tmp/screenshots/screen_1_20250608_120000.png")
    }
    
    @Test("Directory with trailing slash handling", .tags(.fast))
    func directoryWithTrailingSlashHandling() {
        let command = createTestImageCommand(path: "/tmp/screenshots/", screenIndex: nil)
        
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: "/tmp/screenshots/", fileName: fileName)
        
        #expect(result == "/tmp/screenshots//screen_1_20250608_120000.png")
    }
    
    @Test(
        "Various file extensions",
        arguments: [
            "/tmp/image.png",
            "/tmp/photo.jpg", 
            "/tmp/picture.jpeg",
            "/tmp/screen.PNG",
            "/tmp/capture.JPG"
        ]
    )
    func variousFileExtensions(path: String) {
        let command = createTestImageCommand(path: path, screenIndex: nil)
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: path, fileName: fileName)
        
        // Should modify the filename for multiple screens, keeping original extension
        let pathExtension = (path as NSString).pathExtension
        let pathWithoutExtension = (path as NSString).deletingPathExtension
        let expected = "\(pathWithoutExtension)_1_20250608_120000.\(pathExtension)"
        
        #expect(result == expected)
    }
    
    @Test(
        "Edge case paths",
        arguments: [
            ("", false), // Empty path
            ("...", true), // File-like with dots
            ("/", false), // Root directory
            ("/tmp/.hidden", true), // Hidden file
            ("/tmp/.hidden/", false), // Hidden directory
            ("file.tar.gz", true), // Multiple extensions
        ]
    )
    func edgeCasePaths(path: String, expectedAsFile: Bool) {
        let isLikelyFile = path.contains(".") && !path.hasSuffix("/")
        #expect(isLikelyFile == expectedAsFile, "Path '\(path)' detection failed")
    }
    
    @Test("Filename generation with screen suffix extraction", .tags(.fast))
    func filenameSuffixExtraction() {
        let command = createTestImageCommand(path: "/tmp/shot.png", screenIndex: nil)
        
        // Test various filename patterns
        let testCases = [
            (fileName: "screen_1_20250608_120000.png", expected: "/tmp/shot_1_20250608_120000.png"),
            (fileName: "screen_2_20250608_120001.png", expected: "/tmp/shot_2_20250608_120001.png"),
            (fileName: "screen_10_20250608_120002.png", expected: "/tmp/shot_10_20250608_120002.png")
        ]
        
        for testCase in testCases {
            let result = command.determineOutputPath(basePath: "/tmp/shot.png", fileName: testCase.fileName)
            #expect(result == testCase.expected, "Failed for fileName: \(testCase.fileName)")
        }
    }
    
    @Test("Path with special characters", .tags(.fast))
    func pathWithSpecialCharacters() {
        let specialPaths = [
            "/tmp/测试 screenshot.png",
            "/tmp/スクリーン capture.png",
            "/tmp/screen-shot_v2.png",
            "/tmp/my file (1).png"
        ]
        
        for path in specialPaths {
            let command = createTestImageCommand(path: path, screenIndex: 0)
            let fileName = "screen_1_20250608_120000.png"
            let result = command.determineOutputPath(basePath: path, fileName: fileName)
            
            // For single screen, should use exact path
            #expect(result == path, "Failed for special path: \(path)")
        }
    }
    
    @Test("Nested directory path creation logic", .tags(.fast))
    func nestedDirectoryPathCreation() {
        let nestedPaths = [
            "/tmp/very/deep/nested/path/file.png",
            "/home/user/Documents/Screenshots/test.jpg",
            "./relative/deep/path/image.png"
        ]
        
        for path in nestedPaths {
            let command = createTestImageCommand(path: path, screenIndex: 0)
            let fileName = "screen_1_20250608_120000.png"
            let result = command.determineOutputPath(basePath: path, fileName: fileName)
            
            #expect(result == path, "Should return exact path for nested file: \(path)")
            
            // Test parent directory extraction
            let parentDir = (path as NSString).deletingLastPathComponent
            #expect(!parentDir.isEmpty, "Parent directory should be extractable from: \(path)")
        }
    }
    
    @Test("Default path behavior (nil path)", .tags(.fast))
    func defaultPathBehavior() {
        let command = createTestImageCommand(path: nil)
        let fileName = "screen_1_20250608_120000.png"
        let result = command.getOutputPath(fileName)
        
        #expect(result == "/tmp/\(fileName)")
    }
    
    @Test("getOutputPath method delegation", .tags(.fast))
    func getOutputPathDelegation() {
        // Test that getOutputPath properly delegates to determineOutputPath
        let command = createTestImageCommand(path: "/tmp/test.png")
        let fileName = "screen_1_20250608_120000.png"
        let result = command.getOutputPath(fileName)
        
        // Should call determineOutputPath and return its result
        #expect(result.contains("/tmp/test"))
        #expect(result.hasSuffix(".png"))
    }
}

// MARK: - Error Handling Tests

@Suite("ImageCommand Error Handling Tests", .tags(.imageCapture, .unit))
struct ImageCommandErrorHandlingTests {
    
    @Test("Improved file write error messages", .tags(.fast))
    func improvedFileWriteErrorMessages() {
        // Test enhanced error messages with different underlying errors
        
        // Test with permission error
        let permissionError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
            NSLocalizedDescriptionKey: "Permission denied"
        ])
        let fileErrorWithPermission = CaptureError.fileWriteError("/tmp/test.png", permissionError)
        let permissionMessage = fileErrorWithPermission.errorDescription ?? ""
        
        #expect(permissionMessage.contains("Failed to write capture file to path: /tmp/test.png."))
        #expect(permissionMessage.contains("Permission denied - check that the directory is writable"))
        
        // Test with no such file error
        let noFileError = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [
            NSLocalizedDescriptionKey: "No such file or directory"
        ])
        let fileErrorWithNoFile = CaptureError.fileWriteError("/tmp/nonexistent/test.png", noFileError)
        let noFileMessage = fileErrorWithNoFile.errorDescription ?? ""
        
        #expect(noFileMessage.contains("Failed to write capture file to path: /tmp/nonexistent/test.png."))
        #expect(noFileMessage.contains("Directory does not exist - ensure the parent directory exists"))
        
        // Test with disk space error
        let spaceError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError, userInfo: [
            NSLocalizedDescriptionKey: "No space left on device"
        ])
        let fileErrorWithSpace = CaptureError.fileWriteError("/tmp/test.png", spaceError)
        let spaceMessage = fileErrorWithSpace.errorDescription ?? ""
        
        #expect(spaceMessage.contains("Failed to write capture file to path: /tmp/test.png."))
        #expect(spaceMessage.contains("Insufficient disk space available"))
        
        // Test with generic error
        let genericError = NSError(domain: "TestDomain", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "Some generic error"
        ])
        let fileErrorWithGeneric = CaptureError.fileWriteError("/tmp/test.png", genericError)
        let genericMessage = fileErrorWithGeneric.errorDescription ?? ""
        
        #expect(genericMessage.contains("Failed to write capture file to path: /tmp/test.png."))
        #expect(genericMessage.contains("Some generic error"))
        
        // Test with no underlying error
        let fileErrorWithoutUnderlying = CaptureError.fileWriteError("/tmp/test.png", nil)
        let noUnderlyingMessage = fileErrorWithoutUnderlying.errorDescription ?? ""
        
        #expect(noUnderlyingMessage.contains("Failed to write capture file to path: /tmp/test.png."))
        #expect(noUnderlyingMessage.contains("This may be due to insufficient permissions, missing directory, or disk space issues"))
    }
    
    @Test("Error message formatting consistency", .tags(.fast))
    func errorMessageFormattingConsistency() {
        // Test that all error messages end with proper punctuation and format
        let testPath = "/tmp/test/path/file.png"
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let fileError = CaptureError.fileWriteError(testPath, testError)
        let message = fileError.errorDescription ?? ""
        
        // Should contain the path
        #expect(message.contains(testPath))
        
        // Should be properly formatted
        #expect(message.starts(with: "Failed to write capture file to path:"))
        
        // Should have additional context
        #expect(message.count > "Failed to write capture file to path: \(testPath).".count)
    }
    
    @Test("Error exit codes consistency", .tags(.fast))
    func errorExitCodesConsistency() {
        // Test that file write errors maintain proper exit codes
        let fileError1 = CaptureError.fileWriteError("/tmp/test1.png", nil)
        let fileError2 = CaptureError.fileWriteError("/tmp/test2.png", NSError(domain: "Test", code: 1))
        
        #expect(fileError1.exitCode == 17)
        #expect(fileError2.exitCode == 17)
        #expect(fileError1.exitCode == fileError2.exitCode)
    }
    
    @Test("Directory creation error handling", .tags(.fast))
    func directoryCreationErrorHandling() {
        // Test that directory creation failures are handled gracefully
        // This test validates the logic without actually creating directories
        
        var command = ImageCommand()
        command.path = "/tmp/test-path-creation/file.png"
        command.screenIndex = 0
        
        let fileName = "screen_1_20250608_120000.png"
        let result = command.determineOutputPath(basePath: "/tmp/test-path-creation/file.png", fileName: fileName)
        
        // Should return the intended path even if directory creation might fail
        #expect(result == "/tmp/test-path-creation/file.png")
    }
    
    @Test("Path validation edge cases", .tags(.fast))
    func pathValidationEdgeCases() throws {
        let command = try ImageCommand.parse([])
        
        // Test empty path components
        let emptyResult = command.determineOutputPath(basePath: "", fileName: "test.png")
        #expect(emptyResult == "/test.png")
        
        // Test root path
        let rootResult = command.determineOutputPath(basePath: "/", fileName: "test.png")
        #expect(rootResult == "//test.png")
        
        // Test current directory
        let currentResult = command.determineOutputPath(basePath: ".", fileName: "test.png")
        #expect(currentResult == "./test.png")
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
            _ = try ImageCommand.parse(args)
            #expect(shouldParse == true)
        } catch {
            #expect(shouldParse == false)
        }
    }
}
