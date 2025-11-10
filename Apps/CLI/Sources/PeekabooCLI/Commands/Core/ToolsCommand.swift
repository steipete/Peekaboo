@preconcurrency import ArgumentParser
import Foundation
import PeekabooCore
import TachikomaMCP

@MainActor
struct ToolsCommand: OutputFormattable {
    private static let abstractText = "List available tools with filtering and display options"
    private static let descriptionText = "Tools command for listing and filtering available tools"

    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: Self.abstractText,
        discussion: """
        Display all available Peekaboo tools, including both native tools and external MCP server tools.

        Examples:
          peekaboo tools                    # Show all tools (native + external)
          peekaboo tools --native-only      # Show only native Peekaboo tools
          peekaboo tools --mcp-only         # Show only external MCP tools
          peekaboo tools --mcp github       # Show only tools from GitHub server
          peekaboo tools --verbose          # Show detailed information
          peekaboo tools --json-output      # Output in JSON format
        """
    )

    @Flag(name: .long, help: "Show only native Peekaboo tools")
    var nativeOnly = false

    @Flag(name: .long, help: "Show only external MCP tools")
    var mcpOnly = false

    @Option(name: .long, help: "Show tools from specific MCP server")
    var mcp: String?

    @Flag(name: .long, help: "Include disabled servers in output")
    var includeDisabled = false

    @Flag(name: .customLong("no-sort"), help: "Disable alphabetical sorting")
    var noSort = false

    @Flag(name: .long, help: "Group external tools by server")
    var groupByServer = false

    @OptionGroup var runtimeOptions: CommandRuntimeOptions
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }

    var description: String { Self.descriptionText }

    var verbose: Bool {
        if let runtime {
            return runtime.configuration.verbose
        }
        return self.runtimeOptions.verbose
    }

    var jsonOutput: Bool {
        if let runtime {
            return runtime.configuration.jsonOutput
        }
        return self.runtimeOptions.jsonOutput
    }

    private var showDetailedInfo: Bool { self.verbose }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime

        let toolRegistry = MCPToolRegistry()
        let clientManager = TachikomaMCPClientManager.shared

        let nativeTools: [any MCPTool] = [
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            SleepTool(),
            SeeTool(),
            ClickTool(),
            TypeTool(),
            ScrollTool(),
            HotkeyTool(),
            SwipeTool(),
            DragTool(),
            MoveTool(),
            AppTool(),
            WindowTool(),
            MenuTool(),
            MCPAgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ]

        toolRegistry.register(nativeTools)
        await toolRegistry.registerExternalTools(from: clientManager)

        let categorizedTools = await toolRegistry.getToolsBySource()
        let filter = ToolFilter(
            showNativeOnly: nativeOnly,
            showMcpOnly: mcpOnly,
            specificServer: mcp,
            includeDisabled: includeDisabled
        )

        let filteredTools = ToolOrganizer.filter(categorizedTools, with: filter)
        let sortedTools = ToolOrganizer.sort(filteredTools, alphabetically: !self.noSort)

        let displayOptions = ToolDisplayOptions(
            useServerPrefixes: true,
            groupByServer: groupByServer,
            showToolCount: !self.jsonOutput,
            sortAlphabetically: !self.noSort,
            showDescription: self.showDetailedInfo
        )

        if self.jsonOutput {
            try self.outputJSON(tools: sortedTools)
        } else {
            self.outputFormatted(tools: sortedTools, options: displayOptions)
        }
    }

    // MARK: - JSON Output

    @MainActor
    private func outputJSON(tools: CategorizedTools) throws {
        struct ToolInfo: Encodable {
            let name: String
            let description: String
            let source: String
            let server: String?
        }

        struct ExternalTools: Encodable {
            let server: String
            let tools: [ToolInfo]
        }

        struct Summary: Encodable {
            let nativeCount: Int
            let externalCount: Int
            let externalServers: Int
            let totalCount: Int
        }

struct Payload: Encodable {
            let native: [ToolInfo]
            let external: [ExternalTools]
            let summary: Summary
        }

        let nativeTools = tools.native.map { tool in
            ToolInfo(
                name: tool.name,
                description: tool.description,
                source: "native",
                server: nil
            )
        }

        let externalTools = tools.external.map { serverName, serverTools in
            ExternalTools(
                server: serverName,
                tools: serverTools.map { tool in
                    ToolInfo(
                        name: tool.name,
                        description: tool.description,
                        source: "external",
                        server: serverName
                    )
                }
            )
        }

        let summary = Summary(
            nativeCount: tools.native.count,
            externalCount: tools.externalCount,
            externalServers: tools.external.count,
            totalCount: tools.totalCount
        )

        let payload = Payload(native: nativeTools, external: externalTools, summary: summary)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(payload)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    // MARK: - Formatted Output

    private func outputFormatted(tools: CategorizedTools, options: ToolDisplayOptions) {
        if !tools.native.isEmpty || !tools.external.isEmpty {
            print("Available Tools")
            print("===============")
            print()
        }

        if !tools.native.isEmpty {
            print("Native Peekaboo Tools")
            print("---------------------")
            print()
            for tool in tools.native {
                print("• \(tool.name)")
                if options.showDescription {
                    print("  \(tool.description)")
                }
            }
            print()
        }

        if !tools.external.isEmpty {
            print("External MCP Tools")
            print("------------------")
            print()
            for (server, serverTools) in tools.external {
                let serverHeader = options.useServerPrefixes ? "[server] " : ""
                print("\(serverHeader)Server: \(server) — \(serverTools.count) tool\(serverTools.count == 1 ? "" : "s")")

                for tool in serverTools {
                    print("  • \(tool.name)")
                    if options.showDescription {
                        print("    \(tool.description)")
                    }
                }
                print()
            }
        }

        if options.showToolCount {
            print("Summary")
            print("-------")
            print("Native tools: \(tools.native.count)")
            print("External tools: \(tools.externalCount)")
            print("Servers: \(tools.external.count)")
            print("Total: \(tools.totalCount)")
        }
    }
}

extension ToolsCommand: @MainActor AsyncParsableCommand {}

extension ToolsCommand: @MainActor AsyncRuntimeCommand {}
