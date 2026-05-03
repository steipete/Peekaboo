import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore
import Tachikoma
import Testing
@testable import PeekabooCLI

struct CommandRuntimeInjectionTests {
    @Test
    @MainActor
    func `uses the injected service provider`() {
        let services = RecordingPeekabooServices()
        let runtime = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: false, logLevel: nil),
            services: services
        )
        #expect(services.ensureVisualizerConnectionCallCount == 1)
        #expect(runtime.services is RecordingPeekabooServices)
    }

    @Test
    @MainActor
    func `installs MCP/tool defaults when constructed`() {
        let services = RecordingPeekabooServices()
        _ = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: false, logLevel: nil),
            services: services
        )

        let context = MCPToolContext.shared
        #expect(ObjectIdentifier(context.snapshots as AnyObject) ==
            ObjectIdentifier(services.snapshots as AnyObject))

        let tools = ToolRegistry.allTools()
        #expect(!tools.isEmpty)
    }

    @Test
    @MainActor
    func `aligns Tachikoma profile directory with Peekaboo`() {
        let previousProfile = TachikomaConfiguration.profileDirectoryName
        defer { TachikomaConfiguration.profileDirectoryName = previousProfile }

        TachikomaConfiguration.profileDirectoryName = ".tachikoma"
        let services = RecordingPeekabooServices()
        _ = CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: false, logLevel: nil),
            services: services
        )

        #expect(TachikomaConfiguration.profileDirectoryName == ".peekaboo")
    }

    @Test
    func `targeted hotkey support requires enabled bridge operation`() {
        let supported = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .targetedHotkey],
            permissions: PermissionsStatus(
                screenRecording: true,
                accessibility: true,
                postEvent: false
            ),
            enabledOperations: [.captureScreen],
            permissionTags: [
                PeekabooBridgeOperation.targetedHotkey.rawValue: [.postEvent],
            ]
        )

        let enabled = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .targetedHotkey],
            enabledOperations: [.captureScreen, .targetedHotkey]
        )

        #expect(!CommandRuntime.supportsTargetedHotkeys(for: supported))
        #expect(CommandRuntime.supportsTargetedHotkeys(for: enabled))

        let availability = CommandRuntime.targetedHotkeyAvailability(for: supported)
        #expect(availability.unavailableReason?.contains("Event Synthesizing") == true)
        #expect(availability.missingPermissions == [.postEvent])
    }

    @Test
    func `targeted hotkey availability does not require accessibility`() {
        let handshake = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.targetedHotkey],
            permissions: PermissionsStatus(
                screenRecording: true,
                accessibility: false,
                postEvent: true
            ),
            enabledOperations: [.targetedHotkey],
            permissionTags: [
                PeekabooBridgeOperation.targetedHotkey.rawValue: [.postEvent],
            ]
        )

        #expect(CommandRuntime.supportsTargetedHotkeys(for: handshake))
        let availability = CommandRuntime.targetedHotkeyAvailability(for: handshake)
        #expect(availability.isEnabled)
        #expect(availability.unavailableReason == nil)
        #expect(availability.missingPermissions.isEmpty)
    }

    @Test
    func `post event permission request support requires advertised protocol operation`() {
        let supported = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 2),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .requestPostEventPermission]
        )
        let older = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .requestPostEventPermission]
        )
        let hidden = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: PeekabooBridgeProtocolVersion(major: 1, minor: 2),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen]
        )

        #expect(CommandRuntime.supportsPostEventPermissionRequest(for: supported))
        #expect(!CommandRuntime.supportsPostEventPermissionRequest(for: older))
        #expect(!CommandRuntime.supportsPostEventPermissionRequest(for: hidden))
    }
}

@MainActor
final class RecordingPeekabooServices: PeekabooServiceProviding {
    private let base = PeekabooServices()
    private(set) var ensureVisualizerConnectionCallCount = 0

    func ensureVisualizerConnection() {
        self.ensureVisualizerConnectionCallCount += 1
    }

    var logging: any LoggingServiceProtocol {
        self.base.logging
    }

    var screenCapture: any ScreenCaptureServiceProtocol {
        self.base.screenCapture
    }

    var applications: any ApplicationServiceProtocol {
        self.base.applications
    }

    var automation: any UIAutomationServiceProtocol {
        self.base.automation
    }

    var windows: any WindowManagementServiceProtocol {
        self.base.windows
    }

    var menu: any MenuServiceProtocol {
        self.base.menu
    }

    var dock: any DockServiceProtocol {
        self.base.dock
    }

    var dialogs: any DialogServiceProtocol {
        self.base.dialogs
    }

    var snapshots: any SnapshotManagerProtocol {
        self.base.snapshots
    }

    var files: any FileServiceProtocol {
        self.base.files
    }

    var clipboard: any ClipboardServiceProtocol {
        self.base.clipboard
    }

    var configuration: PeekabooCore.ConfigurationManager {
        self.base.configuration
    }

    var process: any ProcessServiceProtocol {
        self.base.process
    }

    var permissions: PermissionsService {
        self.base.permissions
    }

    var audioInput: AudioInputService {
        self.base.audioInput
    }

    var screens: any ScreenServiceProtocol {
        self.base.screens
    }

    var agent: (any AgentServiceProtocol)? {
        self.base.agent
    }
}
