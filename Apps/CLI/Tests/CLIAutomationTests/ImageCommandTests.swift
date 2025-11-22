import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("ImageCommand Tests", .serialized, .tags(.imageCapture, .unit))
@MainActor
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
            try CLIOutputCapture.suppressStderr {
                _ = try ImageCommand.parse(args)
            }
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

    // MARK: - Window Selection Tests

    @Test("Prefers the first renderable main window when overlays exist", .tags(.imageCapture))
    func imageCommandPrefersRenderableWindow() async throws {
        let appName = "iTerm2"
        let overlay = ServiceWindowInfo(
            windowID: 10,
            title: "Command Palette",
            bounds: CGRect(x: 0, y: 0, width: 80, height: 80),
            isMinimized: false,
            isMainWindow: false,
            windowLevel: 0,
            alpha: 1.0,
            index: 0
        )
        let terminal = ServiceWindowInfo(
            windowID: 11,
            title: "zsh — main",
            bounds: CGRect(x: 50, y: 50, width: 1280, height: 720),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 1
        )
        let windows = [overlay, terminal]
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "com.googlecode.iterm2",
            name: appName,
            windowCount: windows.count
        )
        let captureResult = Self.makeCaptureResult(app: appInfo, window: terminal)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var recordedWindowIndex: Int?
        captureService.captureWindowHandler = { identifier, index in
            #expect(identifier == appName)
            recordedWindowIndex = index
            return captureResult
        }

        let applications = StubApplicationService(applications: [appInfo], windowsByApp: [appName: windows])
        let windowService = StubWindowService(windowsByApp: [appName: windows])
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            windows: windowService,
            screenCapture: captureService
        )

        let outputPath = Self.makeTempCapturePath("iterm.png")
        var command = try ImageCommand.parse(["--app", appName, "--path", outputPath])
        command.captureFocus = .background

        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: services
        )

        try await command.run(using: runtime)
        let index = try #require(recordedWindowIndex)
        #expect(index == terminal.index)
        try? FileManager.default.removeItem(atPath: outputPath)
    }

    @Test("Honors --window-title when selecting a window", .tags(.imageCapture))
    func imageCommandMatchesWindowTitle() async throws {
        let appName = "LogsApp"
        let inspector = ServiceWindowInfo(
            windowID: 20,
            title: "Inspector",
            bounds: CGRect(x: 0, y: 0, width: 640, height: 480),
            isMinimized: false,
            isMainWindow: false,
            windowLevel: 0,
            alpha: 1.0,
            index: 0
        )
        let logs = ServiceWindowInfo(
            windowID: 21,
            title: "Server Logs",
            bounds: CGRect(x: 100, y: 80, width: 1024, height: 768),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 1
        )
        let windows = [inspector, logs]
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 5252,
            bundleIdentifier: "dev.logs.app",
            name: appName,
            windowCount: windows.count
        )

        let captureResult = Self.makeCaptureResult(app: appInfo, window: logs)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var recordedWindowIndex: Int?
        captureService.captureWindowHandler = { _, index in
            recordedWindowIndex = index
            return captureResult
        }

        let applications = StubApplicationService(applications: [appInfo], windowsByApp: [appName: windows])
        let windowService = StubWindowService(windowsByApp: [appName: windows])
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            windows: windowService,
            screenCapture: captureService
        )

        let outputPath = Self.makeTempCapturePath("logs.png")
        var command = try ImageCommand.parse([
            "--app", appName,
            "--window-title", "Logs",
            "--path", outputPath,
        ])
        command.captureFocus = .background

        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: services
        )

        try await command.run(using: runtime)
        let index = try #require(recordedWindowIndex)
        #expect(index == logs.index)
        try? FileManager.default.removeItem(atPath: outputPath)
    }

    @Test("Throws when --window-title does not match any window", .tags(.imageCapture))
    func imageCommandThrowsWhenWindowTitleMissing() async throws {
        let appName = "Notes"
        let notesWindow = ServiceWindowInfo(
            windowID: 31,
            title: "All Notes",
            bounds: CGRect(x: 0, y: 0, width: 900, height: 600),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0
        )
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 6060,
            bundleIdentifier: "com.example.notes",
            name: appName,
            windowCount: 1
        )

        let captureService = StubScreenCaptureService(permissionGranted: true)
        let applications = StubApplicationService(applications: [appInfo], windowsByApp: [appName: [notesWindow]])
        let windowService = StubWindowService(windowsByApp: [appName: [notesWindow]])
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            windows: windowService,
            screenCapture: captureService
        )

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--app", appName,
                "--window-title", "Nonexistent",
                "--capture-focus", "background",
                "--path", Self.makeTempCapturePath("notes.png"),
                "--json-output",
            ],
            services: services
        )

        #expect(result.exitStatus == 1)

        let response = try JSONDecoder().decode(
            JSONResponse.self,
            from: Data(result.combinedOutput.utf8)
        )
        #expect(response.success == false)
        #expect(response.error?.code == ErrorCode.WINDOW_NOT_FOUND.rawValue)
    }

    @Test("Skips windows marked non-shareable", .tags(.imageCapture))
    func imageCommandSkipsNonShareableWindows() async throws {
        let appName = "Console"
        let hidden = ServiceWindowInfo(
            windowID: 90,
            title: "Console Overlay",
            bounds: CGRect(x: 0, y: 0, width: 400, height: 200),
            index: 0,
            sharingState: .some(.none)
        )
        let visible = ServiceWindowInfo(
            windowID: 91,
            title: "Logs",
            bounds: CGRect(x: 40, y: 40, width: 1400, height: 900),
            index: 1,
            sharingState: .readWrite
        )

        let appInfo = ServiceApplicationInfo(
            processIdentifier: 7070,
            bundleIdentifier: "dev.console",
            name: appName,
            windowCount: 2
        )

        let captureResult = Self.makeCaptureResult(app: appInfo, window: visible)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var recordedWindowIndex: Int?
        captureService.captureWindowHandler = { _, index in
            recordedWindowIndex = index
            return captureResult
        }

        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: [appInfo], windowsByApp: [appName: [hidden, visible]]),
            windows: StubWindowService(windowsByApp: [appName: [hidden, visible]]),
            screenCapture: captureService
        )

        let path = Self.makeTempCapturePath("console.png")
        var command = try ImageCommand.parse(["--app", appName, "--path", path])
        command.captureFocus = .background

        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: services
        )

        try await command.run(using: runtime)
        let index = try #require(recordedWindowIndex)
        #expect(index == visible.index)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("Errors when only hidden windows remain", .tags(.imageCapture))
    func imageCommandFailsWhenAllWindowsHidden() async throws {
        let appName = "OverlayApp"
        let hidden = ServiceWindowInfo(
            windowID: 101,
            title: "Overlay",
            bounds: CGRect(x: 0, y: 0, width: 500, height: 300),
            sharingState: .some(.none)
        )
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 9090,
            bundleIdentifier: "dev.overlay",
            name: appName,
            windowCount: 1
        )

        let captureService = StubScreenCaptureService(permissionGranted: true)
        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: [appInfo], windowsByApp: [appName: [hidden]]),
            windows: StubWindowService(windowsByApp: [appName: [hidden]]),
            screenCapture: captureService
        )

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--app", appName,
                "--capture-focus", "background",
                "--path", Self.makeTempCapturePath("overlay.png"),
                "--json-output",
            ],
            services: services
        )

        #expect(result.exitStatus == 1)

        let response = try JSONDecoder().decode(
            JSONResponse.self,
            from: Data(result.combinedOutput.utf8)
        )
        #expect(response.success == false)
        #expect(response.error?.code == ErrorCode.WINDOW_NOT_FOUND.rawValue)
    }

    private static func makeTempCapturePath(_ suffix: String) -> String {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent("image-command-tests-\(UUID().uuidString)-\(suffix)")
            .path
    }

    private static func makeCaptureResult(
        app: ServiceApplicationInfo,
        window: ServiceWindowInfo
    ) -> CaptureResult {
        let metadata = CaptureMetadata(
            size: window.bounds.size,
            mode: .window,
            applicationInfo: app,
            windowInfo: window
        )
        return CaptureResult(
            imageData: Data(repeating: 0xAB, count: 32),
            metadata: metadata
        )
    }
}
#endif
