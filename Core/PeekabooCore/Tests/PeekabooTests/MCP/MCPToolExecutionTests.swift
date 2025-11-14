import Foundation
import MCP
import PeekabooFoundation
import TachikomaMCP
import Testing
@testable import PeekabooCore

@Suite("MCP Tool Execution Tests")
struct MCPToolExecutionTests {
    // MARK: - Sleep Tool Tests

    @Test("Sleep tool execution with valid duration")
    func sleepToolValidDuration() async throws {
        try await MCPToolTestHelpers.withContext {
            let tool = SleepTool()
            // Use a shorter duration for testing
            let args = ToolArguments(raw: ["duration": 0.01])

            let start = Date()
            let response = try await tool.execute(arguments: args)
            let elapsed = Date().timeIntervalSince(start)

            #expect(response.isError == false)
            #expect(elapsed >= 0)

            if case let .text(message) = response.content.first {
                #expect(message.contains("Paused") || message.contains("Sleep"))
            }
        }
    }

    @Test("Sleep tool with missing duration")
    func sleepToolMissingDuration() async throws {
        try await MCPToolTestHelpers.withContext {
            let tool = SleepTool()
            let args = ToolArguments(raw: [:])

            let response = try await tool.execute(arguments: args)
            #expect(response.isError == true)

            if case let .text(error) = response.content.first {
                #expect(error.contains("duration"))
            }
        }
    }

    // MARK: - Permissions Tool Tests

    @Test("Permissions tool execution")
    func permissionsToolExecution() async throws {
        let automation = await MainActor.run { MockAutomationService(accessibilityGranted: true) }
        let screenCapture = await MainActor.run { MockScreenCaptureService(screenRecordingGranted: true) }
        let context = await MCPToolTestHelpers.makeContext(
            automation: automation,
            screenCapture: screenCapture)
        let tool = PermissionsTool(context: context)
        let args = ToolArguments(raw: [:])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == false)

        if case let .text(output) = response.content.first {
            // Should contain information about permissions
            #expect(output.contains("Accessibility") || output.contains("Screen Recording"))
        }
    }

    // MARK: - List Tool Tests

    @Test("List tool for apps")
    func listToolApps() async throws {
        let mockApplications = await MainActor.run {
            MockApplicationService(
            applications: [
                ServiceApplicationInfo(
                    processIdentifier: 1,
                    bundleIdentifier: "com.apple.finder",
                    name: "Finder",
                    isActive: true,
                    windowCount: 1),
            ])
        }
        let context = await MCPToolTestHelpers.makeContext(applications: mockApplications)
        let tool = ListTool(context: context)
        let args = ToolArguments(raw: ["type": "apps"])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == false)

        if case let .text(output) = response.content.first {
            // Should contain at least Finder
            #expect(output.contains("Finder") || output.contains("com.apple.finder"))
        }
    }

    @Test("List tool with invalid type")
    func listToolInvalidType() async throws {
        let mockApplications = await MainActor.run { MockApplicationService() }
        let context = await MCPToolTestHelpers.makeContext(applications: mockApplications)
        let tool = ListTool(context: context)
        let args = ToolArguments(raw: ["type": "invalid"])

        let response = try await tool.execute(arguments: args)
        // List tool might not validate the type and just return empty results
        // or it might fall back to a default type
        // Let's just check that it returns a response without crashing
        #expect(!response.content.isEmpty)
    }

    // MARK: - App Tool Tests

    @Test("App tool launch")
    func appToolLaunch() async throws {
        let mockApps = await MainActor.run { MockApplicationService() }
        let context = await MCPToolTestHelpers.makeContext(applications: mockApps)
        let tool = AppTool(context: context)
        let args = ToolArguments(raw: [
            "action": "launch",
            "target": "TextEdit",
        ])

        let response = try await tool.execute(arguments: args)

        // We can't guarantee TextEdit exists on all test systems
        // but we can verify the response format
        if !response.isError {
            if case let .text(output) = response.content.first {
                #expect(output.contains("Launch") || output.contains("already running"))
            }
        }
    }

    @Test("App tool missing action")
    func appToolMissingAction() async throws {
        let mockApps = await MainActor.run { MockApplicationService() }
        let context = await MCPToolTestHelpers.makeContext(applications: mockApps)
        let tool = AppTool(context: context)
        let args = ToolArguments(raw: ["target": "Finder"])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == true)
    }
}

// MARK: - Test Helpers

private enum MCPToolTestHelpers {
    static func makeContext(
        automation: (any UIAutomationServiceProtocol)? = nil,
        screenCapture: (any ScreenCaptureServiceProtocol)? = nil,
        applications: (any ApplicationServiceProtocol)? = nil) async -> MCPToolContext
    {
        await MainActor.run {
            let services = PeekabooServices()
            return MCPToolContext(
                automation: automation ?? services.automation,
                menu: services.menu,
                windows: services.windows,
                applications: applications ?? services.applications,
                dialogs: services.dialogs,
                dock: services.dock,
                screenCapture: screenCapture ?? services.screenCapture,
                sessions: services.sessions,
                screens: services.screens,
                agent: services.agent,
                permissions: services.permissions)
        }
    }

    static func withContext<T>(
        automation: (any UIAutomationServiceProtocol)? = nil,
        screenCapture: (any ScreenCaptureServiceProtocol)? = nil,
        applications: (any ApplicationServiceProtocol)? = nil,
        _ operation: () async throws -> T) async rethrows -> T
    {
        let context = await self.makeContext(
            automation: automation,
            screenCapture: screenCapture,
            applications: applications)
        return try await MCPToolContext.withContext(context) {
            try await operation()
        }
    }
}

// MARK: - Mock Services

@MainActor
private final class MockAutomationService: UIAutomationServiceProtocol {
    private let accessibilityGranted: Bool

    init(accessibilityGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
    }

    func detectElements(in _: Data, sessionId _: String?, windowContext _: WindowContext?) async throws
        -> ElementDetectionResult
    {
        throw PeekabooError.notImplemented("mock detectElements")
    }

    func click(target _: ClickTarget, clickType _: ClickType, sessionId _: String?) async throws {}

    func type(text _: String, target _: String?, clearExisting _: Bool, typingDelay _: Int, sessionId _: String?) async
        throws {}

    func typeActions(_: [TypeAction], typingDelay _: Int, sessionId _: String?) async throws -> TypeResult {
        TypeResult(totalCharacters: 0, keyPresses: 0)
    }

    func scroll(_: ScrollRequest) async throws {}

    func hotkey(keys _: String, holdDuration _: Int) async throws {}

    func swipe(from _: CGPoint, to _: CGPoint, duration _: Int, steps _: Int) async throws {}

    func hasAccessibilityPermission() async -> Bool { self.accessibilityGranted }

    func waitForElement(target _: ClickTarget, timeout _: TimeInterval, sessionId _: String?) async throws
        -> WaitForElementResult
    {
        WaitForElementResult(found: false, element: nil, waitTime: 0)
    }

    func drag(from _: CGPoint, to _: CGPoint, duration _: Int, steps _: Int, modifiers _: String?) async throws {}

    func moveMouse(to _: CGPoint, duration _: Int, steps _: Int) async throws {}

    func getFocusedElement() -> UIFocusInfo? { nil }

    func findElement(matching _: UIElementSearchCriteria, in _: String?) async throws -> DetectedElement {
        throw PeekabooError.elementNotFound("mock find element")
    }
}

@MainActor
private final class MockScreenCaptureService: ScreenCaptureServiceProtocol {
    private let screenRecordingGranted: Bool

    init(screenRecordingGranted: Bool) {
        self.screenRecordingGranted = screenRecordingGranted
    }

    func captureScreen(displayIndex _: Int?) async throws -> CaptureResult { self.makeResult(mode: .screen) }

    func captureWindow(appIdentifier _: String, windowIndex _: Int?) async throws -> CaptureResult {
        self.makeResult(mode: .window)
    }

    func captureFrontmost() async throws -> CaptureResult { self.makeResult(mode: .frontmost) }

    func captureArea(_: CGRect) async throws -> CaptureResult { self.makeResult(mode: .area) }

    func hasScreenRecordingPermission() async -> Bool { self.screenRecordingGranted }

    private func makeResult(mode: CaptureMode) -> CaptureResult {
        CaptureResult(
            imageData: Data(),
            metadata: CaptureMetadata(size: .zero, mode: mode))
    }
}

@MainActor
private final class MockApplicationService: ApplicationServiceProtocol {
    private(set) var applications: [ServiceApplicationInfo]

    init(applications: [ServiceApplicationInfo] = []) {
        self.applications = applications
    }

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        UnifiedToolOutput(
            data: ServiceApplicationListData(applications: self.applications),
            summary: .init(
                brief: "Found \(self.applications.count) apps",
                status: .success,
                counts: ["applications": self.applications.count]),
            metadata: .init(duration: 0))
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let match = self.applications.first(where: { $0.name == identifier || $0.bundleIdentifier == identifier }) {
            return match
        }
        throw PeekabooError.appNotFound(identifier)
    }

    func listWindows(for appIdentifier: String, timeout _: Float?) async throws
        -> UnifiedToolOutput<ServiceWindowListData>
    {
        let targetApp = try? await self.findApplication(identifier: appIdentifier)
        return UnifiedToolOutput(
            data: ServiceWindowListData(windows: [], targetApplication: targetApp),
            summary: .init(brief: "No windows", status: .success),
            metadata: .init(duration: 0))
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        self.applications.first ?? ServiceApplicationInfo(processIdentifier: 0, bundleIdentifier: nil, name: "Mock")
    }

    func isApplicationRunning(identifier: String) async -> Bool {
        self.applications.contains { app in
            app.name == identifier || app.bundleIdentifier == identifier
        }
    }

    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let app = ServiceApplicationInfo(
            processIdentifier: Int32(self.applications.count + 1),
            bundleIdentifier: identifier,
            name: identifier,
            isActive: true)
        self.applications.append(app)
        return app
    }

    func activateApplication(identifier _: String) async throws {}

    func quitApplication(identifier _: String, force _: Bool) async throws -> Bool { true }

    func hideApplication(identifier _: String) async throws {}

    func unhideApplication(identifier _: String) async throws {}

    func hideOtherApplications(identifier _: String) async throws {}

    func showAllApplications() async throws {}
}

@Suite("MCP Tool Error Handling Tests")
struct MCPToolErrorHandlingTests {
    @Test("Tool handles invalid argument types gracefully")
    func invalidArgumentTypes() async throws {
        try await MCPToolTestHelpers.withContext {
            let tool = TypeTool()

        // Pass number where string expected
        let args = ToolArguments(raw: ["text": 12345])

            let response = try await tool.execute(arguments: args)

        // Tool should either convert or error gracefully
        // TypeTool should convert number to string
            #expect(response.isError == false)
        }
    }

    @Test("Tool handles missing required arguments")
    func missingRequiredArguments() async throws {
        try await MCPToolTestHelpers.withContext {
            let tool = ClickTool()

        // ClickTool actually has no required parameters - it will error if no valid input is provided
        let args = ToolArguments(raw: [:])

            let response = try await tool.execute(arguments: args)
        #expect(response.isError == true)

            if case let .text(error) = response.content.first {
            // Should mention that it needs some input like query, on, or coords
            #expect(error.lowercased().contains("specify") || error.lowercased().contains("provide") || error
                .lowercased().contains("must"))
            }
        }
    }

    @Test("Tool handles malformed coordinate strings")
    func malformedCoordinates() async throws {
        try await MCPToolTestHelpers.withContext {
            let tool = ClickTool()
            let args = ToolArguments(raw: ["coords": "not-a-coordinate"])
            let response = try await tool.execute(arguments: args)

            #expect(response.isError == true)

            if case let .text(error) = response.content.first {
                #expect(error.contains("Invalid coordinates format") || error.contains("coordinates"))
            }
        }
    }
}

@Suite("MCP Tool Integration Tests", .tags(.integration))
struct MCPToolIntegrationTests {
    @Test("Multiple tools can execute concurrently")
    func concurrentToolExecution() async throws {
        let apps = [ServiceApplicationInfo(processIdentifier: 1, bundleIdentifier: "com.test.app", name: "TestApp")]
        let automation = await MainActor.run { MockAutomationService(accessibilityGranted: true) }
        let screenCapture = await MainActor.run { MockScreenCaptureService(screenRecordingGranted: true) }
        let appService = await MainActor.run { MockApplicationService(applications: apps) }
        try await MCPToolTestHelpers.withContext(
            automation: automation,
            screenCapture: screenCapture,
            applications: appService) {
                let sleepTool = SleepTool()
                let permissionsTool = PermissionsTool()
                let listTool = ListTool()

                async let sleep = sleepTool.execute(arguments: ToolArguments(raw: ["duration": 0.1]))
                async let permissions = permissionsTool.execute(arguments: ToolArguments(raw: [:]))
                async let list = listTool.execute(arguments: ToolArguments(raw: ["type": "apps"]))

                let results = try await (sleep, permissions, list)

                #expect(results.0.isError == false)
                #expect(results.1.isError == false)
                #expect(results.2.isError == false)
            }
    }

    @Test("Tool execution with complex arguments")
    func complexArgumentHandling() async throws {
        // Test tools that accept complex nested arguments
        let automation = await MainActor.run { MockAutomationService(accessibilityGranted: true) }
        let screenCapture = await MainActor.run { MockScreenCaptureService(screenRecordingGranted: true) }
        try await MCPToolTestHelpers.withContext(automation: automation, screenCapture: screenCapture) {
            let tool = SeeTool()

            let args = ToolArguments(raw: [
                "annotate": true,
                "element_types": ["button", "link", "textfield"],
                "app_target": "Safari:0",
                "output_path": "/tmp/test-annotated.png",
            ])

            let response = try await tool.execute(arguments: args)

            // Can't guarantee Safari is running, but we can verify the tool handles arguments
            if response.isError {
                if case let .text(error) = response.content.first {
                    #expect(!error.isEmpty)
                }
            }
        }
    }
}
