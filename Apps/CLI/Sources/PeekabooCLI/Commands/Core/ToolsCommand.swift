@preconcurrency import ArgumentParser
import Foundation
import OrderedCollections
import PeekabooCore
import TachikomaMCP

@MainActor
struct ToolsCommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List available tools with filtering and display options",
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

    @OptionGroup
    var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private @RuntimeStorage var runtime: CommandRuntime?

    private var jsonOutput: Bool {
        self.runtimeOptions.jsonOutput
    }

    private var showDetailedInfo: Bool {
        self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose
    }

    @Flag(name: .long, help: "Include disabled servers in output")
    var includeDisabled = false

    @Flag(name: .customLong("no-sort"), help: "Disable alphabetical sorting")
    var noSort = false

    @Flag(name: .long, help: "Group external tools by server")
    var groupByServer = false

    /// Gather native and external tool catalogs, apply CLI filters, then emit in the requested format.
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let toolRegistry = MCPToolRegistry()
        let clientManager = TachikomaMCPClientManager.shared

        // Register native Peekaboo tools
        let nativeTools: [any MCPTool] = [
            // Core tools
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            SleepTool(),
            // UI automation tools
            SeeTool(),
            ClickTool(),
            TypeTool(),
            ScrollTool(),
            HotkeyTool(),
            SwipeTool(),
            DragTool(),
            MoveTool(),
            // App management tools
            AppTool(),
            WindowTool(),
            MenuTool(),
            // Advanced tools
            MCPAgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ]

        toolRegistry.register(nativeTools)

        // Register external tools from client manager
        await toolRegistry.registerExternalTools(from: clientManager)

        // Get categorized tools
        let categorizedTools = await toolRegistry.getToolsBySource()

        // Apply filtering
        let filter = ToolFilter(
            showNativeOnly: nativeOnly,
            showMcpOnly: mcpOnly,
            specificServer: mcp,
            includeDisabled: includeDisabled
        )

        let filteredTools = ToolOrganizer.filter(categorizedTools, with: filter)
        let sortedTools = ToolOrganizer.sort(filteredTools, alphabetically: !self.noSort)

        // Configure display options
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
        // Display header
        if !tools.native.isEmpty || !tools.external.isEmpty {
            print("Available Tools")
            print("===============")
            print()
        } else {
            print("No tools available.")
            return
        }

        // Display native tools
        if !tools.native.isEmpty && !self.mcpOnly {
            self.displayNativeTools(tools.native, options: options)
        }

        // Display external tools
        if !tools.external.isEmpty && !self.nativeOnly {
            self.displayExternalTools(tools.external, options: options)
        }

        // Display summary
        if options.showToolCount {
            self.displaySummary(tools: tools)
        }
    }

    @MainActor
    private func displayNativeTools(_ tools: [any MCPTool], options: ToolDisplayOptions) {
        print("Native Tools (\(tools.count)):")

        for tool in tools {
            let name = ToolOrganizer.displayName(for: tool, options: options)

            if options.showDescription {
                let description = ToolOrganizer.formatDescription(tool.description)
                print("  \(name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(description)")
            } else {
                print("  \(name)")
            }
        }
        print()
    }

    @MainActor
    private func displayExternalTools(
        _ toolsByServer: OrderedDictionary<String, [any MCPTool]>,
        options: ToolDisplayOptions
    ) {
        if options.groupByServer {
            // Group by server
            for (serverName, serverTools) in toolsByServer {
                print("\(serverName) Tools (\(serverTools.count)):")

                for tool in serverTools {
                    let name = ToolOrganizer.displayName(for: tool, options: options)

                    if options.showDescription {
                        let description = ToolOrganizer.formatDescription(tool.description)
                        print("  \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(description)")
                    } else {
                        print("  \(name)")
                    }
                }
                print()
            }
        } else {
            // Flat list of external tools
            let allExternalTools = toolsByServer.values.flatMap { $0 }
            print("External Tools (\(allExternalTools.count)):")

            for tool in allExternalTools {
                let name = ToolOrganizer.displayName(for: tool, options: options)

                if options.showDescription {
                    let description = ToolOrganizer.formatDescription(tool.description)
                    print("  \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(description)")
                } else {
                    print("  \(name)")
                }
            }
            print()
        }
    }

    private func displaySummary(tools: CategorizedTools) {
        print("Summary:")
        print("  Native tools: \(tools.native.count)")
        print("  External tools: \(tools.externalCount) from \(tools.external.count) servers")
        print("  Total: \(tools.totalCount) tools")
    }
}

@MainActor
extension ToolsCommand: AsyncRuntimeCommand {}

// MARK: - Tool Filter Extensions

extension ToolFilter {
    /// Validate filter combinations
    private func validate() throws {
        // Validate filter combinations
        if showNativeOnly && showMcpOnly {
            throw ValidationError("Cannot specify both --native-only and --mcp-only")
        }

        if showNativeOnly && specificServer != nil {
            throw ValidationError("Cannot specify both --native-only and --mcp")
        }

        if showMcpOnly && specificServer != nil {
            // This is actually valid - show only tools from specific server
        }
    }
}

extension ToolsCommand: CustomStringConvertible {
    var description: String {
        "Tools command for listing and filtering available tools"
    }
}
