//
//  MCPCallTypes.swift
//  PeekabooCLI
//

import MCP
import PeekabooCore

struct CallJSONPayload: Encodable {
    struct Response: Encodable {
        let isError: Bool
        let content: [SerializableContent]
        let meta: Value?
    }

    let success: Bool
    let server: String
    let tool: String
    let response: Response
    let errorMessage: String?
}

struct SerializableContent: Encodable {
    enum ContentType: String, Encodable {
        case text
        case image
        case resource
        case audio
    }

    let type: ContentType
    let text: String?
    let mimeType: String?
    let data: String?
    let uri: String?
    let metadata: Value?

    init(content: MCP.Tool.Content) {
        switch content {
        case let .text(text):
            self.type = .text
            self.text = text
            self.mimeType = nil
            self.data = nil
            self.uri = nil
            self.metadata = nil
        case let .image(data, mimeType, metadata):
            self.type = .image
            self.text = nil
            self.mimeType = mimeType
            self.data = data
            self.uri = nil
            self.metadata = Self.valueMetadata(from: metadata)
        case let .resource(uri, mimeType, text):
            self.type = .resource
            self.text = text
            self.mimeType = mimeType
            self.data = nil
            self.uri = uri
            self.metadata = nil
        case let .audio(data, mimeType):
            self.type = .audio
            self.text = nil
            self.mimeType = mimeType
            self.data = data
            self.uri = nil
            self.metadata = nil
        }
    }

    private static func valueMetadata(from metadata: [String: String]?) -> Value? {
        guard let metadata else { return nil }
        var object: [String: Value] = [:]
        for (key, value) in metadata {
            object[key] = .string(value)
        }
        return .object(object)
    }
}
