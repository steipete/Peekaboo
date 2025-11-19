import Foundation
import PeekabooAutomation
import Tachikoma
import TachikomaMCP

/// Normalized allow/deny lists used when exposing tools.
public struct ToolFilters: Sendable {
    public let allow: Set<String>
    public let deny: Set<String>
}

@usableFromInline
enum ToolFiltering {
    /// Resolve filters from environment + config with the defined precedence rules.
    static func currentFilters(configuration: ConfigurationManager = .shared) -> ToolFilters {
        let env = ProcessInfo.processInfo.environment
        let envAllow = self.parseList(env["PEEKABOO_ALLOW_TOOLS"])
        let envDeny = self.parseList(env["PEEKABOO_DISABLE_TOOLS"])

        let config = configuration.getConfiguration()
        let configAllow = config?.tools?.allow ?? []
        let configDeny = config?.tools?.deny ?? []

        // env allow replaces config allow when present; deny always accumulates
        let allowList = envAllow?.map(self.normalize) ?? configAllow.map(self.normalize)
        let denyList = (configDeny + (envDeny ?? [])).map(self.normalize)

        return ToolFilters(
            allow: Set(allowList),
            deny: Set(denyList))
    }

    /// Filter AgentTool list.
    static func apply(_ tools: [AgentTool], filters: ToolFilters) -> [AgentTool] {
        self.apply(tools, filters: filters) { $0.name }
    }

    /// Filter MCPTool list.
    static func apply(_ tools: [any MCPTool], filters: ToolFilters) -> [any MCPTool] {
        self.apply(tools, filters: filters) { $0.name }
    }

    // MARK: - Helpers

    private static func apply<T>(
        _ tools: [T],
        filters: ToolFilters,
        nameProvider: (T) -> String) -> [T]
    {
        let allow = filters.allow
        let deny = filters.deny

        // First, enforce allow list if present
        var filtered: [T] = tools
        if !allow.isEmpty {
            filtered = filtered.filter { allow.contains(self.normalize(nameProvider($0))) }
        }

        // Then remove any denies
        if !deny.isEmpty {
            filtered = filtered.filter { !deny.contains(self.normalize(nameProvider($0))) }
        }

        return filtered
    }

    private static func parseList(_ raw: String?) -> [String]? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return raw
            .split { $0 == "," || $0.isWhitespace }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
    }
}
