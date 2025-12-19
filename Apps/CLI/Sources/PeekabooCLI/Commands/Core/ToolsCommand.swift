import Commander
import Foundation
import PeekabooCore
import TachikomaMCP

@MainActor
struct ToolsCommand: OutputFormattable, RuntimeOptionsConfigurable {
    private static let abstractText = "List available tools with filtering and display options"
    private static let descriptionText = "Tools command for listing and filtering available tools"

    static let commandDescription = CommandDescription(
        commandName: "tools",
        abstract: Self.abstractText,
        discussion: """
        Display all available Peekaboo tools exposed to agents and the MCP server.

        Examples:
          peekaboo tools                    # Show all tools
          peekaboo tools --verbose          # Show detailed information
          peekaboo tools --json-output      # Output in JSON format
        """
    )

    @Flag(name: .customLong("no-sort"), help: "Disable alphabetical sorting")
    var noSort = false


    var runtimeOptions = CommandRuntimeOptions()
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }

    var description: String { Self.descriptionText }

    var verbose: Bool { self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose }

    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    private var showDetailedInfo: Bool { self.verbose }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime

        let toolContext = MCPToolContext(services: self.services)

        let nativeTools: [any MCPTool] = [
            ImageTool(context: toolContext),
            CaptureTool(context: toolContext),
            AnalyzeTool(),
            ListTool(context: toolContext),
            PermissionsTool(context: toolContext),
            SleepTool(),
            SeeTool(context: toolContext),
            ClickTool(context: toolContext),
            TypeTool(context: toolContext),
            ScrollTool(context: toolContext),
            HotkeyTool(context: toolContext),
            SwipeTool(context: toolContext),
            DragTool(context: toolContext),
            MoveTool(context: toolContext),
            AppTool(context: toolContext),
            WindowTool(context: toolContext),
            MenuTool(context: toolContext),
            MCPAgentTool(context: toolContext),
            DockTool(context: toolContext),
            DialogTool(context: toolContext),
            SpaceTool(context: toolContext),
        ]

        let filters = ToolFiltering.currentFilters()
        let filteredTools = ToolFiltering.apply(
            nativeTools,
            filters: filters,
            log: { [logger] message in
                logger.notice("\(message, privacy: .public)")
            }
        )
        let sortedTools = self.noSort
            ? filteredTools
            : filteredTools.sorted { $0.name < $1.name }

        if self.jsonOutput {
            try self.outputJSON(tools: sortedTools)
        } else {
            self.outputFormatted(tools: sortedTools, showDescription: self.showDetailedInfo)
        }
    }

    // MARK: - JSON Output

    @MainActor
    private func outputJSON(tools: [any MCPTool]) throws {
        struct ToolInfo: Encodable {
            let name: String
            let description: String
        }

        struct Payload: Encodable {
            let tools: [ToolInfo]
            let count: Int
        }

        let payload = Payload(
            tools: tools.map { ToolInfo(name: $0.name, description: $0.description) },
            count: tools.count
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(payload)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    // MARK: - Formatted Output

    private func outputFormatted(tools: [any MCPTool], showDescription: Bool) {
        if !tools.isEmpty {
            print("Available Tools")
            print("===============")
            print()
        }

        for tool in tools {
            print("• \(tool.name)")
            if showDescription {
                print("  \(tool.description)")
            }
        }

        if !tools.isEmpty {
            print()
            print("Total tools: \(tools.count)")
        }
    }
}

@MainActor
extension ToolsCommand: ParsableCommand {}
extension ToolsCommand: AsyncRuntimeCommand {}

@MainActor
extension ToolsCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.noSort = values.flag("noSort")
    }
}
