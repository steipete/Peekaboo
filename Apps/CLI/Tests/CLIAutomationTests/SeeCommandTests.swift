import CoreGraphics
import Foundation
import PeekabooAutomation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

@Suite("SeeCommand Tests", .serialized, .tags(.safe))
struct SeeCommandTests {
    @Test("See command parses correctly with minimal arguments")
    func parseMinimalArguments() throws {
        let command = try SeeCommand.parse(["--path", "/tmp/test.png"])
        #expect(command.path == "/tmp/test.png")
        #expect(command.app == nil)
        #expect(command.mode == nil) // No longer has default value
        #expect(command.windowTitle == nil)
        #expect(command.annotate == false)
        #expect(command.jsonOutput == false)
    }

    @Test("See command parses all arguments correctly")
    func parseAllArguments() throws {
        let command = try SeeCommand.parse([
            "--app", "Safari",
            "--path", "/tmp/screenshot.png",
            "--annotate",
            "--json",
        ])
        #expect(command.app == "Safari")
        #expect(command.path == "/tmp/screenshot.png")
        #expect(command.annotate == true)
        #expect(command.jsonOutput == true)
    }

    @Test("See command handles different capture modes", arguments: [
        "screen",
        "window",
        "frontmost",
    ])
    func parseCaptureMode(modeString: String) throws {
        let command = try SeeCommand.parse(["--mode", modeString])
        #expect(command.mode?.rawValue == modeString)
    }

    @Test("See command auto-infers window mode when app is specified")
    func autoInferWindowModeWithApp() throws {
        let command = try SeeCommand.parse(["--app", "Safari"])
        #expect(command.app == "Safari")
        #expect(command.mode == nil) // Mode not explicitly set
    }

    @Test("See command parses screen-index parameter")
    func parseScreenIndex() throws {
        let command = try SeeCommand.parse(["--mode", "screen", "--screen-index", "1"])
        #expect(command.mode == .screen)
        #expect(command.screenIndex == 1)
    }

    @Test("See command screen-index only works with screen mode")
    func screenIndexRequiresScreenMode() throws {
        // Should parse without error even if not in screen mode
        let command = try SeeCommand.parse(["--mode", "window", "--screen-index", "0"])
        #expect(command.screenIndex == 0)
        // The validation happens at runtime, not parse time
    }

    @Test("See command handles multi-screen capture defaults")
    func multiScreenDefaults() throws {
        let command = try SeeCommand.parse(["--mode", "screen"])
        #expect(command.screenIndex == nil) // No index means capture all screens
    }

    @Test("See command auto-infers window mode when window title is specified")
    func autoInferWindowModeWithTitle() throws {
        let command = try SeeCommand.parse(["--window-title", "Document"])
        #expect(command.windowTitle == "Document")
        #expect(command.mode == nil) // Mode not explicitly set
    }

    @Test("See result structure contains all required fields")
    func seeResultStructure() {
        let element = UIElementSummary(
            id: "B1",
            role: "button",
            title: "Save",
            label: nil,
            description: nil,
            role_description: nil,
            help: nil,
            identifier: nil,
            is_actionable: true,
            keyboard_shortcut: nil
        )

        let result = SeeResult(
            snapshot_id: "test-123",
            screenshot_raw: "/tmp/screenshot.png",
            screenshot_annotated: "/tmp/screenshot_annotated.png",
            ui_map: "/tmp/snapshot.json",
            application_name: "TestApp",
            window_title: "Test Window",
            is_dialog: false,
            element_count: 10,
            interactable_count: 5,
            capture_mode: "frontmost",
            analysis: nil,
            execution_time: 1.5,
            ui_elements: [element],
            menu_bar: nil
        )

        #expect(result.snapshot_id == "test-123")
        #expect(result.screenshot_raw == "/tmp/screenshot.png")
        #expect(result.screenshot_annotated == "/tmp/screenshot_annotated.png")
        #expect(result.ui_map == "/tmp/snapshot.json")
        #expect(result.ui_elements.count == 1)
        #expect(result.ui_elements.first?.id == "B1")
        #expect(result.application_name == "TestApp")
        #expect(result.window_title == "Test Window")
    }

    @Test("See command validates path parameter")
    func validatePathParameter() {
        // Test that command can be created with valid path
        #expect(throws: Never.self) {
            _ = try SeeCommand.parse(["--path", "/tmp/valid.png"])
        }

        // Test default path generation when not provided
        #expect(throws: Never.self) {
            let command = try SeeCommand.parse([])
            #expect(command.path == nil)
        }
    }

    @Test("See command with analyze option")
    func parseAnalyzeOption() throws {
        let command = try SeeCommand.parse([
            "--analyze", "What is shown in this screenshot?",
        ])
        #expect(command.analyze == "What is shown in this screenshot?")
    }

    @Test("See command with window title")
    func parseWindowTitle() throws {
        let command = try SeeCommand.parse([
            "--app", "Safari",
            "--window-title", "GitHub",
        ])
        #expect(command.app == "Safari")
        #expect(command.windowTitle == "GitHub")
    }
}

@Suite("SeeCommand Runtime Tests", .serialized, .tags(.fast))
struct SeeCommandRuntimeTests {
    @Test("See command stores screenshot metadata and prints summary")
    func seeCommandStoresScreenshot() async throws {
        try await self.withTempConfigEnv { _ in
            let fixture = Self.makeSeeCommandRuntimeFixture()
            let automation = StubAutomationService()
            automation.nextDetectionResult = fixture.detectionResult

            let (context, outputURL) = Self.makeSeeCommandRuntimeContext(
                automation: automation,
                screenCapture: fixture.screenCapture
            )
            defer { try? FileManager.default.removeItem(at: outputURL) }

            let result = try await InProcessCommandRunner.run(
                [
                    "see",
                    "--mode", "frontmost",
                    "--path", outputURL.path,
                ],
                services: context.services
            )

            #expect(result.exitStatus == 0)

            let storedScreenshots = context.snapshots.storedScreenshots[fixture.snapshotId] ?? []
            #expect(storedScreenshots.count == 1)
            #expect(storedScreenshots.first?.path == outputURL.path)
            #expect(storedScreenshots.first?.applicationName == fixture.applicationInfo.name)
            #expect(storedScreenshots.first?.windowTitle == fixture.windowInfo.title)
        }
    }

    @Test("See command JSON includes accessibility metadata fields")
    func seeCommandJsonIncludesAccessibilityMetadata() async throws {
        let fixture = Self.makeSeeCommandRuntimeFixture()
        let automation = StubAutomationService()

        let enrichedElement = DetectedElement(
            id: "B42",
            type: .button,
            label: nil,
            value: nil,
            bounds: CGRect(x: 50, y: 60, width: 34, height: 34),
            isEnabled: true,
            isSelected: nil,
            attributes: [
                "description": "Wingman Grindr Session Helper",
                "roleDescription": "Pop Up Button",
                "help": "Pinned extension button",
                "identifier": "wingman-session-helper"
            ]
        )

        let detectionResult = ElementDetectionResult(
            snapshotId: fixture.snapshotId,
            screenshotPath: fixture.detectionResult.screenshotPath,
            elements: DetectedElements(buttons: [enrichedElement]),
            metadata: fixture.detectionResult.metadata
        )
        automation.nextDetectionResult = detectionResult

        try await self.withTempConfigEnv { _ in
            let (context, outputURL) = Self.makeSeeCommandRuntimeContext(
                automation: automation,
                screenCapture: fixture.screenCapture
            )
            defer { try? FileManager.default.removeItem(at: outputURL) }

            let result = try await InProcessCommandRunner.run(
                [
                    "see",
                    "--mode", "frontmost",
                    "--path", outputURL.path,
                    "--json",
                ],
                services: context.services
            )

            let data = try #require(result.stdout.data(using: .utf8))
            let response = try JSONDecoder().decode(
                CodableJSONResponse<SeeResult>.self,
                from: data
            )
            let element = try #require(response.data.ui_elements.first)

            #expect(response.success == true)
            #expect(element.description == "Wingman Grindr Session Helper")
            #expect(element.role_description == "Pop Up Button")
            #expect(element.help == "Pinned extension button")
            #expect(element.identifier == "wingman-session-helper")
        }
    }

    private func withTempConfigEnv<T>(
        _ body: @escaping (URL) async throws -> T
    ) async throws -> T {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        setenv("PEEKABOO_CONFIG_DIR", tempDir.path, 1)
        setenv("PEEKABOO_CONFIG_NONINTERACTIVE", "1", 1)
        setenv("PEEKABOO_CONFIG_DISABLE_MIGRATION", "1", 1)
        #if DEBUG
        ConfigurationManager.shared.resetForTesting()
        #endif

        defer {
            unsetenv("PEEKABOO_CONFIG_DIR")
            unsetenv("PEEKABOO_CONFIG_NONINTERACTIVE")
            unsetenv("PEEKABOO_CONFIG_DISABLE_MIGRATION")
            #if DEBUG
            ConfigurationManager.shared.resetForTesting()
            #endif
            try? FileManager.default.removeItem(at: tempDir)
        }

        return try await body(tempDir)
    }
}

extension SeeCommandRuntimeTests {
    fileprivate struct RuntimeFixture {
        let snapshotId: String
        let applicationInfo: ServiceApplicationInfo
        let windowInfo: ServiceWindowInfo
        let screenCapture: StubScreenCaptureService
        let detectionResult: ElementDetectionResult
    }

    fileprivate static func makeSeeCommandRuntimeFixture() -> RuntimeFixture {
        let snapshotId = UUID().uuidString
        let windowBounds = CGRect(x: 10, y: 20, width: 800, height: 600)
        let applicationInfo = Self.makeSeeFixtureApplicationInfo()
        let windowInfo = Self.makeSeeFixtureWindowInfo(windowBounds: windowBounds)
        let captureResult = Self.makeSeeFixtureCaptureResult(
            applicationInfo: applicationInfo,
            windowInfo: windowInfo
        )
        let screenCapture = Self.makeSeeFixtureScreenCapture(captureResult: captureResult)
        let detectionResult = Self.makeSeeFixtureDetectionResult(
            snapshotId: snapshotId,
            applicationInfo: applicationInfo,
            windowInfo: windowInfo,
            windowBounds: windowBounds
        )

        return RuntimeFixture(
            snapshotId: snapshotId,
            applicationInfo: applicationInfo,
            windowInfo: windowInfo,
            screenCapture: screenCapture,
            detectionResult: detectionResult
        )
    }

    fileprivate static func makeSeeCommandRuntimeContext(
        automation: StubAutomationService,
        screenCapture: StubScreenCaptureService
    ) -> (context: TestServicesFactory.AutomationTestContext, outputURL: URL) {
        let context = TestServicesFactory.makeAutomationTestContext(
            automation: automation,
            screenCapture: screenCapture
        )
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-see-runtime.png")
        return (context, outputURL)
    }

    fileprivate static func makeSeeFixtureApplicationInfo() -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "com.example.app",
            name: "ExampleApp",
            isActive: true,
            windowCount: 1
        )
    }

    fileprivate static func makeSeeFixtureWindowInfo(windowBounds: CGRect) -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: 101,
            title: "Main Window",
            bounds: windowBounds,
            isMainWindow: true
        )
    }

    fileprivate static func makeSeeFixtureCaptureResult(
        applicationInfo: ServiceApplicationInfo,
        windowInfo: ServiceWindowInfo
    ) -> CaptureResult {
        let metadata = CaptureMetadata(
            size: CGSize(width: 1280, height: 720),
            mode: .window,
            applicationInfo: applicationInfo,
            windowInfo: windowInfo
        )
        return CaptureResult(imageData: Data(repeating: 0xAB, count: 1024), metadata: metadata)
    }

    fileprivate static func makeSeeFixtureScreenCapture(captureResult: CaptureResult) -> StubScreenCaptureService {
        let screenCapture = StubScreenCaptureService(permissionGranted: true)
        screenCapture.defaultCaptureResult = captureResult
        return screenCapture
    }

    fileprivate static func makeSeeFixtureDetectionResult(
        snapshotId: String,
        applicationInfo: ServiceApplicationInfo,
        windowInfo: ServiceWindowInfo,
        windowBounds: CGRect
    ) -> ElementDetectionResult {
        let detectedElement = DetectedElement(
            id: "B1",
            type: .button,
            label: "OK",
            bounds: CGRect(x: 30, y: 40, width: 100, height: 30)
        )
        let detectionMetadata = DetectionMetadata(
            detectionTime: 0.1,
            elementCount: 1,
            method: "stub",
            windowContext: WindowContext(
                applicationName: applicationInfo.name,
                windowTitle: windowInfo.title,
                windowBounds: windowBounds
            )
        )
        return ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/ignored.png",
            elements: DetectedElements(buttons: [detectedElement]),
            metadata: detectionMetadata
        )
    }
}
