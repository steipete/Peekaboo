import Foundation

public struct PeekabooBridgeBrowserInfo: Codable, Sendable, Equatable {
    public let name: String
    public let bundleIdentifier: String
    public let processIdentifier: Int32
    public let version: String?
    public let channel: String

    public init(
        name: String,
        bundleIdentifier: String,
        processIdentifier: Int32,
        version: String?,
        channel: String)
    {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.version = version
        self.channel = channel
    }
}

public struct PeekabooBridgeBrowserStatus: Codable, Sendable, Equatable {
    public let isConnected: Bool
    public let toolCount: Int
    public let detectedBrowsers: [PeekabooBridgeBrowserInfo]
    public let error: String?

    public init(
        isConnected: Bool,
        toolCount: Int,
        detectedBrowsers: [PeekabooBridgeBrowserInfo],
        error: String? = nil)
    {
        self.isConnected = isConnected
        self.toolCount = toolCount
        self.detectedBrowsers = detectedBrowsers
        self.error = error
    }
}

public struct PeekabooBridgeBrowserChannelRequest: Codable, Sendable, Equatable {
    public let channel: String?

    public init(channel: String? = nil) {
        self.channel = channel
    }
}

public struct PeekabooBridgeBrowserExecuteRequest: Codable, Sendable, Equatable {
    public let toolName: String
    public let arguments: [String: PeekabooBridgeJSONValue]
    public let channel: String?

    public init(
        toolName: String,
        arguments: [String: PeekabooBridgeJSONValue],
        channel: String? = nil)
    {
        self.toolName = toolName
        self.arguments = arguments
        self.channel = channel
    }
}

public struct PeekabooBridgeBrowserToolResponse: Codable, Sendable, Equatable {
    public let content: [PeekabooBridgeJSONValue]
    public let isError: Bool
    public let meta: PeekabooBridgeJSONValue?

    public init(content: [PeekabooBridgeJSONValue], isError: Bool, meta: PeekabooBridgeJSONValue?) {
        self.content = content
        self.isError = isError
        self.meta = meta
    }
}
