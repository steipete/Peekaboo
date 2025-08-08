import ArgumentParser
import Foundation
import PeekabooCore
import TachikomaMCP

struct ToolsCommand: AsyncParsableCommand {
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
    
    @Flag(name: .long, help: "Show detailed tool information")
    var verbose = false
    
    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false
    
    @Flag(name: .long, help: "Include disabled servers in output")
    var includeDisabled = false
    
    @Flag(name: .long, help: "Sort tools alphabetically (default: true)")
    var sort = false
    
    @Flag(name: .long, help: "Group external tools by server")
    var groupByServer = false
    
    func run() async throws {
        let toolRegistry = await MCPToolRegistry()
        let clientManager = await TachikomaMCPClientManager.shared
        
        // Register native Peekaboo tools
        let nativeTools: [MCPTool] = [
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
        
        await toolRegistry.register(nativeTools)
        
        // Debug: Check if tools were registered
        let allToolsCount = await toolRegistry.allTools().count
        print("DEBUG: Registered \(nativeTools.count) native tools, registry now has \(allToolsCount) total tools")
        
        // Register external tools from client manager
        await toolRegistry.registerExternalTools(from: clientManager)
        
        // Get categorized tools
        let categorizedTools = await toolRegistry.getToolsBySource()
        print("DEBUG: Categorized tools - Native: \(categorizedTools.native.count), External: \(categorizedTools.externalCount)")
        
        // Apply filtering
        let filter = ToolFilter(
            showNativeOnly: nativeOnly,
            showMcpOnly: mcpOnly,
            specificServer: mcp,
            includeDisabled: includeDisabled
        )
        
        let filteredTools = ToolOrganizer.filter(categorizedTools, with: filter)
        let sortedTools = ToolOrganizer.sort(filteredTools, alphabetically: !sort) // sort flag inverts default
        
        // Configure display options
        let displayOptions = ToolDisplayOptions(
            useServerPrefixes: true,
            groupByServer: groupByServer,
            showToolCount: !jsonOutput,
            sortAlphabetically: !sort,
            showDescription: verbose
        )
        
        if jsonOutput {
            try outputJSON(tools: sortedTools)
        } else {
            await outputFormatted(tools: sortedTools, options: displayOptions)
        }
    }
    
    // MARK: - JSON Output
    
    private func outputJSON(tools: CategorizedTools) throws {
        var output: [String: Any] = [:]
        
        // Native tools
        output["native"] = tools.native.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "source": "native"
            ]
        }
        
        // External tools
        var externalOutput: [String: Any] = [:]
        for (serverName, serverTools) in tools.external {
            externalOutput[serverName] = serverTools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "source": "external",
                    "server": serverName
                ]
            }
        }
        output["external"] = externalOutput
        
        // Summary
        output["summary"] = [
            "native_count": tools.native.count,
            "external_count": tools.externalCount,
            "external_servers": tools.external.count,
            "total_count": tools.totalCount
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    // MARK: - Formatted Output
    
    private func outputFormatted(tools: CategorizedTools, options: ToolDisplayOptions) async {
        let clientManager = await TachikomaMCPClientManager.shared
        
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
        if !tools.native.isEmpty && !mcpOnly {
            displayNativeTools(tools.native, options: options)
        }
        
        // Display external tools
        if !tools.external.isEmpty && !nativeOnly {
            await displayExternalTools(tools.external, options: options, clientManager: clientManager)
        }
        
        // Display summary
        if options.showToolCount {
            displaySummary(tools: tools)
        }
    }
    
    private func displayNativeTools(_ tools: [MCPTool], options: ToolDisplayOptions) {
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
    
    private func displayExternalTools(
        _ toolsByServer: [String: [MCPTool]], 
        options: ToolDisplayOptions,
        clientManager: TachikomaMCPClientManager
    ) async {
        if options.groupByServer {
            // Group by server
            for (serverName, serverTools) in toolsByServer.sorted(by: { $0.key < $1.key }) {
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

// MARK: - Tool Filter Extensions

private extension ToolFilter {
    /// Validate filter combinations
    func validate() throws {
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