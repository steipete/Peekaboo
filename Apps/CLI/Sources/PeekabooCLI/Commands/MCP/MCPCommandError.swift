//
//  MCPCommandError.swift
//  PeekabooCLI
//

import Foundation
import PeekabooCore

enum MCPCommandError: LocalizedError {
    case invalidArguments(String)
    case serverNotConfigured(String)
    case serverDisabled(String)
    case connectionFailed(server: String, reason: String?)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message):
            message
        case let .serverNotConfigured(server):
            "MCP server '\(server)' is not configured. Use 'peekaboo mcp add' to register it."
        case let .serverDisabled(server):
            "MCP server '\(server)' is disabled. Run 'peekaboo mcp enable \(server)' before calling tools."
        case let .connectionFailed(server, reason):
            if let reason, !reason.isEmpty {
                "Failed to connect to MCP server '\(server)' (\(reason))."
            } else {
                "Failed to connect to MCP server '\(server)'."
            }
        }
    }

    var errorCode: ErrorCode {
        switch self {
        case .invalidArguments, .serverNotConfigured, .serverDisabled:
            .INVALID_ARGUMENT
        case .connectionFailed:
            .UNKNOWN_ERROR
        }
    }
}
