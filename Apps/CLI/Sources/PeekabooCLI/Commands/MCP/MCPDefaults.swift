//
//  MCPDefaults.swift
//  PeekabooCLI
//

import Foundation
import TachikomaMCP

enum MCPDefaults {
    static let serverName = "chrome-devtools"
}

/// Factory for the built-in Chrome DevTools MCP server configuration.
enum ChromeDevToolsServerFactory {
    static func tachikomaConfig(
        timeout: TimeInterval = 15.0,
        autoReconnect: Bool = true
    ) -> TachikomaMCP.MCPServerConfig {
        let details = self.resolveCommandDetails()
        return TachikomaMCP.MCPServerConfig(
            transport: details.transport,
            command: details.command,
            args: details.arguments,
            env: [:],
            enabled: true,
            timeout: timeout,
            autoReconnect: autoReconnect,
            description: "Chrome DevTools automation"
        )
    }

    private static func resolveCommandDetails() -> (transport: String, command: String, arguments: [String]) {
        if let local = self.localBinaryPath() {
            ("stdio", local, ["--isolated"])
        } else if self.hasExecutable(named: "pnpm") {
            ("stdio", "pnpm", ["dlx", "chrome-devtools-mcp@latest", "--", "--isolated"])
        } else {
            ("stdio", "npx", ["-y", "chrome-devtools-mcp@latest", "--", "--isolated"])
        }
    }

    private static func hasExecutable(named name: String) -> Bool {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let fileManager = FileManager.default

        for path in paths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name).path
            if fileManager.isExecutableFile(atPath: candidate) {
                return true
            }
        }
        return false
    }

    private static func localBinaryPath() -> String? {
        let cwd = FileManager.default.currentDirectoryPath
        let path = URL(fileURLWithPath: cwd)
            .appendingPathComponent("node_modules/.bin/chrome-devtools-mcp")
            .path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
