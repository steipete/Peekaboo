import AppKit
import Foundation
import MCP
import TachikomaMCP

public struct BrowserMCPStatus: Sendable {
    public let isConnected: Bool
    public let toolCount: Int
    public let detectedBrowsers: [DetectedBrowser]
    public let error: String?

    public init(isConnected: Bool, toolCount: Int, detectedBrowsers: [DetectedBrowser], error: String? = nil) {
        self.isConnected = isConnected
        self.toolCount = toolCount
        self.detectedBrowsers = detectedBrowsers
        self.error = error
    }
}

public struct DetectedBrowser: Sendable {
    public let name: String
    public let bundleIdentifier: String
    public let processIdentifier: Int32
    public let version: String?
    public let channel: BrowserMCPChannel

    public init(
        name: String,
        bundleIdentifier: String,
        processIdentifier: Int32,
        version: String?,
        channel: BrowserMCPChannel)
    {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.version = version
        self.channel = channel
    }
}

public enum BrowserMCPChannel: String, Sendable, CaseIterable {
    case stable
    case beta
    case dev
    case canary

    static func infer(bundleIdentifier: String, applicationName: String) -> Self? {
        let bundle = bundleIdentifier.lowercased()
        let name = applicationName.lowercased()

        if bundle == "com.google.chrome" || name == "google chrome" {
            return .stable
        }
        if bundle.contains("chrome.beta") || name.contains("chrome beta") {
            return .beta
        }
        if bundle.contains("chrome.dev") || name.contains("chrome dev") {
            return .dev
        }
        if bundle.contains("chrome.canary") || name.contains("canary") {
            return .canary
        }
        return nil
    }
}

public protocol BrowserMCPClientProviding: AnyObject, Sendable {
    @MainActor
    func status(channel: BrowserMCPChannel?) async -> BrowserMCPStatus
    @MainActor
    func connect(channel: BrowserMCPChannel?) async throws -> BrowserMCPStatus
    @MainActor
    func disconnect() async
    @MainActor
    func execute(toolName: String, arguments: [String: Any], channel: BrowserMCPChannel?) async throws -> ToolResponse
}

public final class BrowserMCPService: BrowserMCPClientProviding, @unchecked Sendable {
    private static let serverName = "chrome-devtools"

    private var manager: TachikomaMCPClientManager?

    public init() {
        self.manager = nil
    }

    @MainActor
    public init(manager: TachikomaMCPClientManager) {
        self.manager = manager
    }

    @MainActor
    public func status(channel: BrowserMCPChannel? = nil) async -> BrowserMCPStatus {
        let browserChannel = channel ?? self.preferredChannel()
        let manager = self.resolvedManager()
        let isConnected = await manager.isServerConnected(name: Self.serverName)
        let tools = await manager.getServerTools(name: Self.serverName)
        return BrowserMCPStatus(
            isConnected: isConnected,
            toolCount: tools.count,
            detectedBrowsers: Self.detectRunningBrowsers(channel: browserChannel),
            error: nil)
    }

    @MainActor
    public func connect(channel: BrowserMCPChannel? = nil) async throws -> BrowserMCPStatus {
        let browserChannel = channel ?? self.preferredChannel()
        let config = Self.chromeDevToolsConfig(channel: browserChannel)
        let manager = self.resolvedManager()
        if manager.getServerConfig(name: Self.serverName) == nil {
            try await manager.addServer(name: Self.serverName, config: config)
        } else {
            await manager.removeServer(name: Self.serverName)
            try await manager.addServer(name: Self.serverName, config: config)
        }
        return await self.status(channel: browserChannel)
    }

    @MainActor
    public func disconnect() async {
        await self.resolvedManager().disableServer(name: Self.serverName)
    }

    @MainActor
    public func execute(
        toolName: String,
        arguments: [String: Any],
        channel: BrowserMCPChannel? = nil) async throws -> ToolResponse
    {
        let manager = self.resolvedManager()
        if await !manager.isServerConnected(name: Self.serverName) {
            _ = try await self.connect(channel: channel)
        }
        return try await manager.executeTool(
            serverName: Self.serverName,
            toolName: toolName,
            arguments: arguments)
    }

    public static func chromeDevToolsConfig(channel: BrowserMCPChannel?) -> MCPServerConfig {
        let resolvedChannel = channel ?? .stable
        let args = [
            "-y",
            "chrome-devtools-mcp@latest",
            "--auto-connect",
            "--channel=\(resolvedChannel.rawValue)",
            "--no-usage-statistics",
            "--no-performance-crux",
        ]
        return MCPServerConfig(
            transport: "stdio",
            command: "npx",
            args: args,
            enabled: true,
            timeout: 30,
            autoReconnect: true,
            description: "Chrome DevTools automation for the running \(resolvedChannel.rawValue) Chrome profile")
    }

    public static func detectRunningBrowsers(channel: BrowserMCPChannel? = nil) -> [DetectedBrowser] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard !application.isTerminated else { return nil }
            guard let name = application.localizedName else { return nil }
            guard let bundleIdentifier = application.bundleIdentifier else { return nil }
            guard let inferred = BrowserMCPChannel.infer(
                bundleIdentifier: bundleIdentifier,
                applicationName: name)
            else {
                return nil
            }
            if let channel, channel != inferred {
                return nil
            }

            return DetectedBrowser(
                name: name,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: application.processIdentifier,
                version: self.version(for: application),
                channel: inferred)
        }
    }

    private func preferredChannel() -> BrowserMCPChannel {
        Self.detectRunningBrowsers().first?.channel ?? .stable
    }

    @MainActor
    private func resolvedManager() -> TachikomaMCPClientManager {
        if let manager {
            return manager
        }
        let manager = TachikomaMCPClientManager()
        self.manager = manager
        return manager
    }

    private static func version(for application: NSRunningApplication) -> String? {
        guard let url = application.bundleURL,
              let bundle = Bundle(url: url)
        else {
            return nil
        }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
