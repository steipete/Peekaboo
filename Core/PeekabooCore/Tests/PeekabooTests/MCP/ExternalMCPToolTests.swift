import Foundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

/// Tests for ExternalMCPTool functionality
@Suite("External MCP Tool Tests")
struct ExternalMCPToolTests {
    @Test("ExternalMCPTool initialization and properties")
    @MainActor
    func externalToolProperties() async {
        let clientManager = TachikomaMCPClientManager.shared

        // Create a mock tool info
        let originalTool = Tool(
            name: "test_tool",
            description: "A test tool for external MCP",
            inputSchema: .object(["param": .string("test")]))

        let externalTool = ExternalMCPTool(
            serverName: "test-server",
            originalTool: originalTool,
            clientManager: clientManager)

        // Test properties
        #expect(externalTool.name == "test-server:test_tool")
        #expect(externalTool.description == "[test-server] A test tool for external MCP")
        #expect(externalTool.serverName == "test-server")
        #expect(externalTool.originalTool.name == "test_tool")

        // Test input schema is preserved
        if case let .object(schema) = externalTool.inputSchema {
            #expect(schema["param"] != nil)
        } else {
            Issue.record("Expected object schema")
        }
    }

    @Test("ExternalMCPTool name prefixing")
    @MainActor
    func toolNamePrefixing() async {
        let clientManager = TachikomaMCPClientManager.shared

        let originalTool = Tool(
            name: "create_file",
            description: "Create a new file",
            inputSchema: .object([:]))

        let externalTool = ExternalMCPTool(
            serverName: "filesystem",
            originalTool: originalTool,
            clientManager: clientManager)

        #expect(externalTool.name == "filesystem:create_file")
        #expect(externalTool.description == "[filesystem] Create a new file")
    }
}

/// Tests for CategorizedTools struct
@Suite("Categorized Tools Tests")
struct CategorizedToolsTests {
    @Test("CategorizedTools initialization and properties")
    @MainActor
    func categorizedToolsProperties() async {
        let clientManager = TachikomaMCPClientManager.shared

        // Create mock native tools
        let nativeTool1 = MockMCPTool(name: "native1", description: "Native tool 1")
        let nativeTool2 = MockMCPTool(name: "native2", description: "Native tool 2")
        let nativeTools = [nativeTool1, nativeTool2]

        // Create mock external tools
        let externalTool1 = ExternalMCPTool(
            serverName: "server1",
            originalTool: Tool(name: "external1", description: "External tool 1", inputSchema: .object([:])),
            clientManager: clientManager)
        let externalTool2 = ExternalMCPTool(
            serverName: "server1",
            originalTool: Tool(name: "external2", description: "External tool 2", inputSchema: .object([:])),
            clientManager: clientManager)
        let externalTool3 = ExternalMCPTool(
            serverName: "server2",
            originalTool: Tool(name: "external3", description: "External tool 3", inputSchema: .object([:])),
            clientManager: clientManager)

        let externalTools = [
            "server1": [externalTool1, externalTool2] as [any MCPTool],
            "server2": [externalTool3] as [any MCPTool],
        ]

        let categorized = CategorizedTools(native: nativeTools, external: externalTools)

        // Test counts
        #expect(categorized.native.count == 2)
        #expect(categorized.external.count == 2)
        #expect(categorized.externalCount == 3)
        #expect(categorized.totalCount == 5)

        // Test server-specific queries
        #expect(categorized.tools(from: "server1").count == 2)
        #expect(categorized.tools(from: "server2").count == 1)
        #expect(categorized.tools(from: "nonexistent").isEmpty)

        #expect(categorized.hasTools(from: "server1") == true)
        #expect(categorized.hasTools(from: "server2") == true)
        #expect(categorized.hasTools(from: "nonexistent") == false)

        // Test all external tools
        let allExternal = categorized.allExternalTools
        #expect(allExternal.count == 3)
        #expect(allExternal.contains { $0.name == "server1:external1" })
        #expect(allExternal.contains { $0.name == "server1:external2" })
        #expect(allExternal.contains { $0.name == "server2:external3" })
    }
}

/// Tests for ToolFilter struct
@Suite("Tool Filter Tests")
struct ToolFilterTests {
    @Test("ToolFilter presets")
    func toolFilterPresets() {
        let all = ToolFilter.all
        #expect(all.showNativeOnly == false)
        #expect(all.showMcpOnly == false)
        #expect(all.specificServer == nil)
        #expect(all.includeDisabled == false)

        let nativeOnly = ToolFilter.nativeOnly
        #expect(nativeOnly.showNativeOnly == true)
        #expect(nativeOnly.showMcpOnly == false)

        let mcpOnly = ToolFilter.mcpOnly
        #expect(mcpOnly.showNativeOnly == false)
        #expect(mcpOnly.showMcpOnly == true)

        let serverFilter = ToolFilter.server("test-server")
        #expect(serverFilter.specificServer == "test-server")
        #expect(serverFilter.showNativeOnly == false)
        #expect(serverFilter.showMcpOnly == false)
    }

    @Test("ToolFilter custom initialization")
    func toolFilterCustom() {
        let customFilter = ToolFilter(
            showNativeOnly: true,
            showMcpOnly: false,
            specificServer: "custom-server",
            includeDisabled: true)

        #expect(customFilter.showNativeOnly == true)
        #expect(customFilter.showMcpOnly == false)
        #expect(customFilter.specificServer == "custom-server")
        #expect(customFilter.includeDisabled == true)
    }
}

/// Tests for ToolDisplayOptions struct
@Suite("Tool Display Options Tests")
struct ToolDisplayOptionsTests {
    @Test("ToolDisplayOptions presets")
    func displayOptionsPresets() {
        let defaultOptions = ToolDisplayOptions.default
        #expect(defaultOptions.useServerPrefixes == true)
        #expect(defaultOptions.groupByServer == false)
        #expect(defaultOptions.showToolCount == true)
        #expect(defaultOptions.sortAlphabetically == true)
        #expect(defaultOptions.showDescription == true)

        let compact = ToolDisplayOptions.compact
        #expect(compact.showDescription == false)
        #expect(compact.showToolCount == false)

        let verbose = ToolDisplayOptions.verbose
        #expect(verbose.groupByServer == true)
        #expect(verbose.showDescription == true)
    }

    @Test("ToolDisplayOptions custom initialization")
    func displayOptionsCustom() {
        let customOptions = ToolDisplayOptions(
            useServerPrefixes: false,
            groupByServer: true,
            showToolCount: false,
            sortAlphabetically: false,
            showDescription: false)

        #expect(customOptions.useServerPrefixes == false)
        #expect(customOptions.groupByServer == true)
        #expect(customOptions.showToolCount == false)
        #expect(customOptions.sortAlphabetically == false)
        #expect(customOptions.showDescription == false)
    }
}

/// Tests for ToolOrganizer functionality
@Suite("Tool Organizer Tests")
struct ToolOrganizerTests {
    @Test("ToolOrganizer filtering")
    @MainActor
    func toolFiltering() async {
        let clientManager = TachikomaMCPClientManager.shared

        // Create test tools
        let nativeTools = [
            MockMCPTool(name: "native1", description: "Native tool 1"),
            MockMCPTool(name: "native2", description: "Native tool 2"),
        ]

        let externalTools = [
            "server1": [
                ExternalMCPTool(
                    serverName: "server1",
                    originalTool: Tool(name: "external1", description: "External tool 1", inputSchema: .object([:])),
                    clientManager: clientManager),
            ] as [any MCPTool],
            "server2": [
                ExternalMCPTool(
                    serverName: "server2",
                    originalTool: Tool(name: "external2", description: "External tool 2", inputSchema: .object([:])),
                    clientManager: clientManager),
            ] as [any MCPTool],
        ]

        let originalTools = CategorizedTools(native: nativeTools, external: externalTools)

        // Test native-only filter
        let nativeOnlyFilter = ToolFilter.nativeOnly
        let nativeFiltered = ToolOrganizer.filter(originalTools, with: nativeOnlyFilter)
        #expect(nativeFiltered.native.count == 2)
        #expect(nativeFiltered.external.isEmpty)

        // Test MCP-only filter
        let mcpOnlyFilter = ToolFilter.mcpOnly
        let mcpFiltered = ToolOrganizer.filter(originalTools, with: mcpOnlyFilter)
        #expect(mcpFiltered.native.isEmpty)
        #expect(mcpFiltered.external.count == 2)

        // Test specific server filter
        let serverFilter = ToolFilter.server("server1")
        let serverFiltered = ToolOrganizer.filter(originalTools, with: serverFilter)
        #expect(serverFiltered.native.isEmpty)
        #expect(serverFiltered.external.count == 1)
        #expect(serverFiltered.external["server1"]?.count == 1)
        #expect(serverFiltered.external["server2"] == nil)

        // Test all filter (no filtering)
        let allFilter = ToolFilter.all
        let allFiltered = ToolOrganizer.filter(originalTools, with: allFilter)
        #expect(allFiltered.native.count == 2)
        #expect(allFiltered.external.count == 2)
    }

    @Test("ToolOrganizer sorting")
    @MainActor
    func toolSorting() async {
        let clientManager = TachikomaMCPClientManager.shared

        // Create unsorted native tools
        let nativeTools = [
            MockMCPTool(name: "zebra", description: "Last tool"),
            MockMCPTool(name: "alpha", description: "First tool"),
            MockMCPTool(name: "beta", description: "Middle tool"),
        ]

        // Create unsorted external tools
        let externalTools = [
            "server1": [
                ExternalMCPTool(
                    serverName: "server1",
                    originalTool: Tool(name: "zulu", description: "Last external", inputSchema: .object([:])),
                    clientManager: clientManager),
                ExternalMCPTool(
                    serverName: "server1",
                    originalTool: Tool(name: "alpha", description: "First external", inputSchema: .object([:])),
                    clientManager: clientManager),
            ] as [any MCPTool],
        ]

        let originalTools = CategorizedTools(native: nativeTools, external: externalTools)

        // Test alphabetical sorting
        let sortedTools = ToolOrganizer.sort(originalTools, alphabetically: true)

        // Check native tools are sorted
        let sortedNativeNames = sortedTools.native.map(\.name)
        #expect(sortedNativeNames == ["alpha", "beta", "zebra"])

        // Check external tools are sorted
        let sortedExternalNames = sortedTools.external["server1"]?.map(\.name) ?? []
        #expect(sortedExternalNames == ["server1:alpha", "server1:zulu"])

        // Test no sorting
        let unsortedTools = ToolOrganizer.sort(originalTools, alphabetically: false)
        #expect(unsortedTools.native.count == 3)
        #expect(unsortedTools.external["server1"]?.count == 2)
        // Order should be preserved when not sorting
    }

    @Test("ToolOrganizer display names")
    @MainActor
    func displayNames() async {
        let clientManager = TachikomaMCPClientManager.shared

        let nativeTool = MockMCPTool(name: "native_tool", description: "Native tool")

        let externalTool = ExternalMCPTool(
            serverName: "test-server",
            originalTool: Tool(name: "external_tool", description: "External tool", inputSchema: .object([:])),
            clientManager: clientManager)

        // Test with prefixes
        let withPrefixes = ToolDisplayOptions(useServerPrefixes: true)
        #expect(ToolOrganizer.displayName(for: nativeTool, options: withPrefixes) == "native_tool")
        #expect(ToolOrganizer.displayName(for: externalTool, options: withPrefixes) == "test-server:external_tool")

        // Test without prefixes
        let withoutPrefixes = ToolDisplayOptions(useServerPrefixes: false)
        #expect(ToolOrganizer.displayName(for: nativeTool, options: withoutPrefixes) == "native_tool")
        #expect(ToolOrganizer.displayName(for: externalTool, options: withoutPrefixes) == "external_tool")
    }

    @Test("ToolOrganizer description formatting")
    func descriptionFormatting() {
        let shortDescription = "Short description"
        let longDescription = "This is a very long description that exceeds the maximum length " +
            "and should be truncated properly with ellipsis"

        // Test short description (no truncation)
        let shortFormatted = ToolOrganizer.formatDescription(shortDescription, maxLength: 50)
        #expect(shortFormatted == shortDescription)

        // Test long description (truncation)
        let longFormatted = ToolOrganizer.formatDescription(longDescription, maxLength: 50)
        #expect(longFormatted.count == 50)
        #expect(longFormatted.hasSuffix("..."))
        #expect(longFormatted.hasPrefix("This is a very long description"))

        // Test exact length
        let exactDescription = "This description is exactly fifty characters long!"
        let exactFormatted = ToolOrganizer.formatDescription(exactDescription, maxLength: 50)
        #expect(exactFormatted == exactDescription)
    }
}

/// Tests for ToolSource enum
@Suite("Tool Source Tests")
struct ToolSourceTests {
    @Test("ToolSource display names")
    func toolSourceDisplayNames() {
        let native = ToolSource.native
        #expect(native.displayName == "Native")

        let external = ToolSource.external(serverName: "github")
        #expect(external.displayName == "github")

        let anotherExternal = ToolSource.external(serverName: "filesystem")
        #expect(anotherExternal.displayName == "filesystem")
    }
}

// MARK: - Mock Classes

/// Mock MCP tool for testing
private struct MockMCPTool: MCPTool {
    let name: String
    let description: String
    let inputSchema: MCP.Value = .object([:])

    func execute(arguments: ToolArguments) async throws -> ToolResponse {
        ToolResponse.text("Mock response for \(self.name)")
    }
}
