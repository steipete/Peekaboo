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
            services: services)
        #expect(services.ensureVisualizerConnectionCallCount == 1)
        #expect(runtime.services is RecordingPeekabooServices)
    }
}

@MainActor
final class RecordingPeekabooServices: PeekabooServiceProviding {
    private let base = PeekabooServices()
    private(set) var ensureVisualizerConnectionCallCount = 0

    func ensureVisualizerConnection() {
        self.ensureVisualizerConnectionCallCount += 1
    }

    var logging: any LoggingServiceProtocol { base.logging }
    var screenCapture: any ScreenCaptureServiceProtocol { base.screenCapture }
    var applications: any ApplicationServiceProtocol { base.applications }
    var automation: any UIAutomationServiceProtocol { base.automation }
    var windows: any WindowManagementServiceProtocol { base.windows }
    var menu: any MenuServiceProtocol { base.menu }
    var dock: any DockServiceProtocol { base.dock }
    var dialogs: any DialogServiceProtocol { base.dialogs }
    var sessions: any SessionManagerProtocol { base.sessions }
    var files: any FileServiceProtocol { base.files }
    var configuration: PeekabooCore.ConfigurationManager { base.configuration }
    var process: any ProcessServiceProtocol { base.process }
    var permissions: PermissionsService { base.permissions }
    var audioInput: AudioInputService { base.audioInput }
    var screens: any ScreenServiceProtocol { base.screens }
    var agent: (any AgentServiceProtocol)? { base.agent }
}
