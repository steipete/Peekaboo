import Foundation
import PeekabooAutomation

/// Aggregated service provider protocol exposed to higher-level modules.
@MainActor
public protocol PeekabooServiceProviding: AnyObject, Sendable {
    var logging: any LoggingServiceProtocol { get }
    var screenCapture: any ScreenCaptureServiceProtocol { get }
    var applications: any ApplicationServiceProtocol { get }
    var automation: any UIAutomationServiceProtocol { get }
    var windows: any WindowManagementServiceProtocol { get }
    var menu: any MenuServiceProtocol { get }
    var dock: any DockServiceProtocol { get }
    var dialogs: any DialogServiceProtocol { get }
    var snapshots: any SnapshotManagerProtocol { get }
    var files: any FileServiceProtocol { get }
    var clipboard: any ClipboardServiceProtocol { get }
    var configuration: ConfigurationManager { get }
    var process: any ProcessServiceProtocol { get }
    var permissions: PermissionsService { get }
    var audioInput: AudioInputService { get }
    var screens: any ScreenServiceProtocol { get }
    var agent: (any AgentServiceProtocol)? { get }

    func ensureVisualizerConnection()
}

@MainActor
extension PeekabooServiceProviding {
    /// Install this service container as the default provider for MCP tool contexts and registry helpers.
    public func installAgentRuntimeDefaults() {
        MCPToolContext.configureDefaultContext { [unowned services = self] in
            MCPToolContext(services: services)
        }

        ToolRegistry.configureDefaultServices { [unowned services = self] in
            services
        }
    }
}
