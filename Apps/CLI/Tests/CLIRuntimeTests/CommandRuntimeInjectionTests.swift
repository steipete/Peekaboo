import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("CommandRuntime Dependency Injection")
struct CommandRuntimeInjectionTests {
    @Test("uses the injected service provider")
    @MainActor
    func usesInjectedServices() {
        let services = RecordingPeekabooServices()
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: false, logLevel: nil),
            services: services
        )
        #expect(services.ensureVisualizerConnectionCallCount == 1)
        #expect(runtime.services is RecordingPeekabooServices)
    }

    @Test("installs MCP/tool defaults when constructed")
    @MainActor
    func installsAgentRuntimeDefaults() {
        let services = RecordingPeekabooServices()
        _ = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: false, logLevel: nil),
            services: services
        )

        let context = MCPToolContext.shared
        #expect(ObjectIdentifier(context.sessions as AnyObject) ==
            ObjectIdentifier(services.sessions as AnyObject))

        let tools = ToolRegistry.allTools()
        #expect(!tools.isEmpty)
    }
}

@MainActor
final class RecordingPeekabooServices: PeekabooServiceProviding {
    private let base = PeekabooServices()
    private(set) var ensureVisualizerConnectionCallCount = 0

    func ensureVisualizerConnection() {
        self.ensureVisualizerConnectionCallCount += 1
    }

    var logging: any LoggingServiceProtocol { self.base.logging }
    var screenCapture: any ScreenCaptureServiceProtocol { self.base.screenCapture }
    var applications: any ApplicationServiceProtocol { self.base.applications }
    var automation: any UIAutomationServiceProtocol { self.base.automation }
    var windows: any WindowManagementServiceProtocol { self.base.windows }
    var menu: any MenuServiceProtocol { self.base.menu }
    var dock: any DockServiceProtocol { self.base.dock }
    var dialogs: any DialogServiceProtocol { self.base.dialogs }
    var sessions: any SessionManagerProtocol { self.base.sessions }
    var files: any FileServiceProtocol { self.base.files }
    var clipboard: any ClipboardServiceProtocol { self.base.clipboard }
    var configuration: PeekabooCore.ConfigurationManager { self.base.configuration }
    var process: any ProcessServiceProtocol { self.base.process }
    var permissions: PermissionsService { self.base.permissions }
    var audioInput: AudioInputService { self.base.audioInput }
    var screens: any ScreenServiceProtocol { self.base.screens }
    var agent: (any AgentServiceProtocol)? { self.base.agent }
}
