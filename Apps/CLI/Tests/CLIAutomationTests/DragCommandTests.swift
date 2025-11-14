import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Drag Command Tests", .serialized, .tags(.safe), .enabled(if: CLITestEnvironment.runAutomationRead))
struct DragCommandTests {
    @Test("Drag command exists")
    func dragCommandExists() {
        let config = DragCommand.commandDescription
        #expect(config.commandName == "drag")
        #expect(config.abstract.contains("drag and drop"))
    }

    @Test("Drag command parameters")
    func dragParameters() async throws {
        let result = try await self.runDragCommand(["drag", "--help"])
        #expect(result.exitStatus == 0)
        let output = self.output(from: result)

        #expect(output.contains("--from"))
        #expect(output.contains("--to"))
        #expect(output.contains("--from-coords"))
        #expect(output.contains("--to-coords"))
        #expect(output.contains("--to-app"))
        #expect(output.contains("--duration"))
        #expect(output.contains("--modifiers"))
    }

    @Test("Drag command validation - from required")
    func dragFromRequired() async throws {
        // Test missing from
        let result = try await self.runDragCommand(["drag", "--to", "B1"])
        #expect(result.exitStatus != 0)
    }

    @Test("Drag command validation - to required")
    func dragToRequired() async throws {
        // Test missing to
        let result = try await self.runDragCommand(["drag", "--from", "B1"])
        #expect(result.exitStatus != 0)
    }

    @Test("Drag coordinate parsing")
    func dragCoordinateParsing() {
        // Test valid coordinates
        let coords1 = "100,200"
        let parts1 = coords1.split(separator: ",")
        #expect(parts1.count == 2)
        #expect(Double(parts1[0]) == 100)
        #expect(Double(parts1[1]) == 200)

        // Test coordinates with spaces
        let coords2 = "100, 200"
        let parts2 = coords2.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(Double(parts2[0]) == 100)
        #expect(Double(parts2[1]) == 200)
    }

    @Test("Drag modifier parsing")
    func dragModifierParsing() {
        let modifiers = "cmd,shift"
        let parts = modifiers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(parts.contains("cmd"))
        #expect(parts.contains("shift"))
    }

    @Test("Drag error codes")
    func dragErrorCodes() {
        #expect(ErrorCode.NO_POINT_SPECIFIED.rawValue == "NO_POINT_SPECIFIED")
        #expect(ErrorCode.INVALID_COORDINATES.rawValue == "INVALID_COORDINATES")
        #expect(ErrorCode.SESSION_NOT_FOUND.rawValue == "SESSION_NOT_FOUND")
    }

    @Test("Drag duration validation")
    func dragDurationValidation() {
        // Test that duration is positive
        let validDurations = [100, 500, 1000, 2000]
        for duration in validDurations {
            let cmd = ["drag", "--from", "A1", "--to", "B1", "--duration", "\(duration)"]
            #expect(cmd.count == 7)
        }
    }

    @Test("Drag executes automation service")
    func dragExecutesAutomation() async throws {
        let arguments = [
            "drag",
            "--from-coords", "10,20",
            "--to-coords", "30,40",
            "--duration", "750",
            "--steps", "5",
            "--modifiers", "cmd,option",
            "--json-output",
            "--no-auto-focus",
        ]
        let (result, context) = try await self.runDragCommandWithContext(arguments)
        #expect(result.exitStatus == 0)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(Int(call.from.x) == 10)
        #expect(Int(call.from.y) == 20)
        #expect(Int(call.to.x) == 30)
        #expect(Int(call.to.y) == 40)
        #expect(call.duration == 750)
        #expect(call.steps == 5)
        #expect(call.modifiers == "cmd,option")
    }

    @Test("Drag between coordinates scenario")
    func dragBetweenCoordinatesScenario() async throws {
        let arguments = [
            "drag",
            "--from-coords", "100,100",
            "--to-coords", "300,300",
            "--duration", "500",
            "--json-output",
            "--no-auto-focus",
        ]
        let (result, context) = try await self.runDragCommandWithContext(arguments)
        #expect(result.exitStatus == 0)
        let payload = try JSONDecoder().decode(DragResult.self, from: self.output(from: Data(result).utf8))
        #expect(payload.success)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(Int(call.from.x) == 100)
        #expect(Int(call.from.y) == 100)
        #expect(Int(call.to.x) == 300)
        #expect(Int(call.to.y) == 300)
        #expect(call.duration == 500)
    }

    @Test("Drag from element to coordinates scenario")
    func dragElementToCoordsScenario() async throws {
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Source",
            bounds: CGRect(x: 10, y: 20, width: 40, height: 20)
        )
        let arguments = [
            "drag",
            "--from", "B1",
            "--to-coords", "500,500",
            "--session", "test-session",
            "--json-output",
            "--no-auto-focus",
        ]
        let (result, context) = try await self.runDragCommandWithContext(arguments) { automation, _ in
            automation.setWaitForElementResult(
                WaitForElementResult(found: true, element: element, waitTime: 0.05),
                for: .elementId("B1")
            )
        }
        #expect(result.exitStatus == 0)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(Int(call.from.x) == 30)
        #expect(Int(call.from.y) == 30)
        #expect(Int(call.to.x) == 500)
        #expect(Int(call.to.y) == 500)
    }

    @Test("Drag with modifiers scenario")
    func dragWithModifiersScenario() async throws {
        let arguments = [
            "drag",
            "--from-coords", "200,200",
            "--to-coords", "400,400",
            "--modifiers", "cmd,option",
            "--json-output",
        ]
        let (result, context) = try await self.runDragCommandWithContext(arguments)
        #expect(result.exitStatus == 0)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(call.modifiers == "cmd,option")
    }

    @Test("Drag to application scenario")
    func dragToApplicationScenario() async throws {
        let (applicationService, windowService) = await MainActor.run { () -> (
            StubApplicationService,
            StubWindowService
        ) in
            let finderInfo = ServiceApplicationInfo(
                processIdentifier: 101,
                bundleIdentifier: "com.apple.finder",
                name: "Finder",
                windowCount: 1
            )
            let window = ServiceWindowInfo(
                windowID: 1,
                title: "Finder",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
            )
            let appService = StubApplicationService(applications: [finderInfo], windowsByApp: ["Finder": [window]])
            let winService = StubWindowService(windowsByApp: ["Finder": [window]])
            return (appService, winService)
        }

        let arguments = [
            "drag",
            "--from-coords", "100,100",
            "--to-app", "Finder",
            "--json-output",
        ]

        let (result, context) = try await self.runDragCommandWithContext(
            arguments,
            applications: applicationService,
            windows: windowService
        )
        #expect(result.exitStatus == 0)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(Int(call.to.x) == 400)
        #expect(Int(call.to.y) == 300)
    }

    @Test("Drag with custom duration scenario")
    func dragCustomDurationScenario() async throws {
        let arguments = [
            "drag",
            "--from-coords", "50,50",
            "--to-coords", "150,150",
            "--duration", "2000",
            "--json-output",
        ]
        let (result, context) = try await self.runDragCommandWithContext(arguments)
        #expect(result.exitStatus == 0)
        let dragCalls = await self.automationState(context) { $0.dragCalls }
        let call = try #require(dragCalls.first)
        #expect(call.duration == 2000)
    }
}

extension DragCommandTests {
    fileprivate func runDragCommand(
        _ args: [String],
        configure: (@MainActor (StubAutomationService, StubSessionManager) -> Void)? = nil
    ) async throws -> CommandRunResult {
        let (result, _) = try await self.runDragCommandWithContext(args, configure: configure)
        return result
    }

    fileprivate func runDragCommandWithContext(
        _ args: [String],
        applications: ApplicationServiceProtocol? = nil,
        windows: WindowManagementServiceProtocol? = nil,
        configure: (@MainActor (StubAutomationService, StubSessionManager) -> Void)? = nil
    ) async throws -> (CommandRunResult, TestServicesFactory.AutomationTestContext) {
        let context = await self.makeAutomationContext(applications: applications, windows: windows)
        if let configure {
            await MainActor.run {
                configure(context.automation, context.sessions)
            }
        }
        let result = try await InProcessCommandRunner.run(args, services: context.services)
        return (result, context)
    }

    fileprivate func makeAutomationContext(
        applications: ApplicationServiceProtocol? = nil,
        windows: WindowManagementServiceProtocol? = nil
    ) async -> TestServicesFactory.AutomationTestContext {
        await MainActor.run {
            TestServicesFactory.makeAutomationTestContext(
                applications: applications ?? StubApplicationService(applications: []),
                windows: windows ?? StubWindowService(windowsByApp: [:])
            )
        }
    }

    fileprivate func automationState<T: Sendable>(
        _ context: TestServicesFactory.AutomationTestContext,
        _ operation: @MainActor (StubAutomationService) -> T
    ) async -> T {
        await MainActor.run {
            operation(context.automation)
        }
    }

    fileprivate func output(from result: CommandRunResult) -> String {
        result.stdout.isEmpty ? result.stderr : result.stdout
    }
}

#endif
