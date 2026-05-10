import Foundation
import MCP
import PeekabooAgentRuntime
import PeekabooBridge
import TachikomaMCP

public final class RemoteBrowserMCPClient: BrowserMCPClientProviding, @unchecked Sendable {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    @MainActor
    public func status(channel: BrowserMCPChannel?) async -> BrowserMCPStatus {
        do {
            return try await Self.status(from: self.client.browserStatus(channel: channel?.rawValue))
        } catch {
            return BrowserMCPStatus(
                isConnected: false,
                toolCount: 0,
                detectedBrowsers: [],
                error: error.localizedDescription)
        }
    }

    @MainActor
    public func connect(channel: BrowserMCPChannel?) async throws -> BrowserMCPStatus {
        try await Self.status(from: self.client.browserConnect(channel: channel?.rawValue))
    }

    @MainActor
    public func disconnect() async {
        try? await self.client.browserDisconnect()
    }

    @MainActor
    public func execute(
        toolName: String,
        arguments: [String: Any],
        channel: BrowserMCPChannel?) async throws -> ToolResponse
    {
        let request = try PeekabooBridgeBrowserExecuteRequest(
            toolName: toolName,
            arguments: arguments.mapValues { try PeekabooBridgeJSONValue.fromAny($0) },
            channel: channel?.rawValue)
        let response = try await self.client.browserExecute(request)
        return try Self.toolResponse(from: response)
    }

    private static func status(from bridgeStatus: PeekabooBridgeBrowserStatus) -> BrowserMCPStatus {
        BrowserMCPStatus(
            isConnected: bridgeStatus.isConnected,
            toolCount: bridgeStatus.toolCount,
            detectedBrowsers: bridgeStatus.detectedBrowsers.compactMap { browser in
                guard let channel = BrowserMCPChannel(rawValue: browser.channel) else { return nil }
                return DetectedBrowser(
                    name: browser.name,
                    bundleIdentifier: browser.bundleIdentifier,
                    processIdentifier: browser.processIdentifier,
                    version: browser.version,
                    channel: channel)
            },
            error: bridgeStatus.error)
    }

    private static func toolResponse(from bridgeResponse: PeekabooBridgeBrowserToolResponse) throws -> ToolResponse {
        let content: [MCP.Tool.Content] = try bridgeResponse.content.map { value in
            try self.decode(MCP.Tool.Content.self, from: value)
        }
        let meta: Value? = try bridgeResponse.meta.map { try self.decode(Value.self, from: $0) }
        return ToolResponse(content: content, isError: bridgeResponse.isError, meta: meta)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from value: PeekabooBridgeJSONValue) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value.toAny(), options: [])
        return try JSONDecoder().decode(type, from: data)
    }
}
