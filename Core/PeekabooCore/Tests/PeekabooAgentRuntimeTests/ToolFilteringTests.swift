import Foundation
import PeekabooAutomation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime

@Suite("Tool filtering")
struct ToolFilteringTests {
    @Test("Config allow list narrows tools")
    func configAllowList() throws {
        try withTempConfig(
            """
            {
              "tools": {
                "allow": ["see", "click"]
              }
            }
            """) {
                let filters = ToolFiltering.currentFilters()
                let tools = makeTools(["see", "click", "type"])
                var logs: [String] = []
                let filtered = ToolFiltering.apply(tools, filters: filters, log: { logs.append($0) }).map(\.name)
                #expect(filtered == ["see", "click"])
                #expect(logs.contains { $0.contains("type") && $0.contains("allow list") })
            }
    }

    @Test("Env allow overrides config allow; deny accumulates")
    func envOverridesConfig() throws {
        try withTempConfig(
            """
            {
              "tools": {
                "allow": ["see"],
                "deny": ["shell"]
              }
            }
            """,
            env: [
                "PEEKABOO_ALLOW_TOOLS": "see,type",
                "PEEKABOO_DISABLE_TOOLS": "type",
            ]) {
                let filters = ToolFiltering.currentFilters()
                let tools = makeTools(["see", "type", "shell"])
                var logs: [String] = []
                let filtered = ToolFiltering.apply(tools, filters: filters, log: { logs.append($0) }).map(\.name)
                #expect(filtered == ["see"])
                #expect(filters.deny.contains("type"))
                #expect(filters.deny.contains("shell"))
                #expect(logs.contains { $0.contains("type") && $0.contains("environment") })
                #expect(logs.contains { $0.contains("shell") && $0.contains("config") })
            }
    }

    @Test("Hyphenated names normalize to snake_case")
    func normalizesNames() throws {
        try withTempConfig(
            """
            {
              "tools": {
                "deny": ["menu-click"]
              }
            }
            """) {
                let filters = ToolFiltering.currentFilters()
                let tools = makeTools(["menu_click", "see"])
                let names = ToolFiltering.apply(tools, filters: filters, log: nil).map(\.name)
                #expect(!names.contains("menu_click"))
                #expect(names.contains("see"))
            }
    }
}

// MARK: - Helpers

private func makeTools(_ names: [String]) -> [AgentTool] {
    names.map { name in
        AgentTool(
            name: name,
            description: "tool \(name)",
            parameters: .init(),
            execute: { _ in AnyAgentToolValue(string: name) })
    }
}

private func withTempConfig(
    _ json: String,
    env: [String: String] = [:],
    _ perform: () throws -> Void) throws
{
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    let configURL = dir.appendingPathComponent("config.json")
    try json.write(to: configURL, atomically: true, encoding: .utf8)

    var restore: [String: String?] = [:]
    restore["PEEKABOO_CONFIG_DIR"] = ProcessInfo.processInfo.environment["PEEKABOO_CONFIG_DIR"]
    setenv("PEEKABOO_CONFIG_DIR", dir.path, 1)

    for (key, value) in env {
        restore[key] = ProcessInfo.processInfo.environment[key]
        setenv(key, value, 1)
    }

    defer {
        for (key, value) in restore {
            if let value {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
        try? fm.removeItem(at: dir)
    }

    ConfigurationManager.shared.resetForTesting()
    _ = ConfigurationManager.shared.loadConfiguration()

    try perform()
}
