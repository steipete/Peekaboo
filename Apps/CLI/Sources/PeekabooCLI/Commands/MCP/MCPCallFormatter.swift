//
//  MCPCallFormatter.swift
//  PeekabooCLI
//

import Foundation
import Logging
import MCP
import PeekabooCore
import TachikomaMCP

enum MCPCallFormatter {
    static func outputJSON(
        response: ToolResponse,
        serverName: String,
        toolName: String,
        logger: Logger
    ) {
        let payload = self.makeJSONPayload(for: response, serverName: serverName, toolName: toolName)
        outputJSONCodable(payload, logger: logger)
    }

    static func outputHumanReadable(response: ToolResponse, server: String, toolName: String) {
        print("MCP server: \(server)")
        print("Tool: \(toolName)")

        if response.content.isEmpty {
            print("Response: (no content)")
        } else if response.content.count == 1 {
            print("Response: \(self.describe(content: response.content[0]))")
        } else {
            print("Response:")
            for (index, content) in response.content.indexed() {
                print("  \(index + 1). \(self.describe(content: content))")
            }
        }

        if let metaDescription = self.describe(meta: response.meta) {
            print("Meta: \(metaDescription)")
        }

        if response.isError {
            print("Tool reported an error.")
        } else {
            print("Tool completed successfully.")
        }
    }

    static func emitError(message: String, code: ErrorCode, wantsJSON: Bool, logger: Logger) {
        if wantsJSON {
            let debugLogs = logger.getDebugLogs()
            let response = JSONResponse(
                success: false,
                messages: nil,
                debugLogs: debugLogs,
                error: ErrorInfo(message: message, code: code)
            )
            PeekabooCLI.outputJSON(response, logger: logger)
        } else {
            print("❌ \(message)")
        }
    }

    private static func makeJSONPayload(
        for response: ToolResponse,
        serverName: String,
        toolName: String
    ) -> CallJSONPayload {
        let contents = response.content.map(SerializableContent.init)
        return CallJSONPayload(
            success: !response.isError,
            server: serverName,
            tool: toolName,
            response: .init(isError: response.isError, content: contents, meta: response.meta),
            errorMessage: self.extractErrorMessage(from: response)
        )
    }

    private static func describe(content: MCP.Tool.Content) -> String {
        switch content {
        case let .text(text):
            text
        case let .image(_, mimeType, _):
            "Image response (\(mimeType))"
        case let .resource(uri, _, text):
            if let text, !text.isEmpty {
                "Resource: \(uri) — \(text)"
            } else {
                "Resource: \(uri)"
            }
        case let .audio(_, mimeType):
            "Audio response (\(mimeType))"
        }
    }

    private static func describe(meta: Value?) -> String? {
        guard let meta else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(meta), let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func extractErrorMessage(from response: ToolResponse) -> String? {
        guard response.isError else { return nil }
        for content in response.content {
            if case let .text(text) = content {
                return text
            }
        }
        return nil
    }
}
