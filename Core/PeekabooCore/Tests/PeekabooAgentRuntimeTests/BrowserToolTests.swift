import MCP
import PeekabooCore
import TachikomaMCP
import Testing
@testable import PeekabooAgentRuntime

@MainActor
struct BrowserToolTests {
    @Test
    func `Chrome DevTools config uses auto connect and privacy flags`() {
        let config = BrowserMCPService.chromeDevToolsConfig(channel: .beta)

        #expect(config.command == "npx")
        #expect(config.args.contains("chrome-devtools-mcp@latest"))
        #expect(config.args.contains("--auto-connect"))
        #expect(config.args.contains("--channel=beta"))
        #expect(config.args.contains("--no-usage-statistics"))
        #expect(config.args.contains("--no-performance-crux"))
    }

    @Test
    func `Chrome DevTools config can launch isolated headless browser for deterministic tests`() {
        let config = BrowserMCPService.chromeDevToolsConfig(
            channel: .stable,
            environment: [
                "PEEKABOO_BROWSER_MCP_ISOLATED": "1",
                "PEEKABOO_BROWSER_MCP_HEADLESS": "true",
            ])

        #expect(!config.args.contains("--auto-connect"))
        #expect(config.args.contains("--isolated"))
        #expect(config.args.contains("--headless"))
        #expect(config.args.contains("--channel=stable"))
        #expect(config.args.contains("--no-usage-statistics"))
        #expect(config.args.contains("--no-performance-crux"))
    }

    @Test
    func `Chrome DevTools config can target explicit browser URL`() {
        let config = BrowserMCPService.chromeDevToolsConfig(
            channel: .canary,
            environment: [
                "PEEKABOO_BROWSER_MCP_BROWSER_URL": "http://127.0.0.1:9222",
            ])

        #expect(!config.args.contains("--auto-connect"))
        #expect(!config.args.contains("--channel=canary"))
        #expect(config.args.contains("--browserUrl=http://127.0.0.1:9222"))
        #expect(config.args.contains("--no-usage-statistics"))
        #expect(config.args.contains("--no-performance-crux"))
    }

    @Test
    func `Browser call mapper maps common actions`() throws {
        let click = try BrowserMCPCallMapper.map(
            action: .click,
            arguments: ToolArguments(raw: ["uid": "1_2", "double": true, "include_snapshot": true]))
        #expect(click.toolName == "click")
        #expect(click.arguments["uid"] as? String == "1_2")
        #expect(click.arguments["dblClick"] as? Bool == true)
        #expect(click.arguments["includeSnapshot"] as? Bool == true)

        let navigate = try BrowserMCPCallMapper.map(
            action: .navigate,
            arguments: ToolArguments(raw: ["url": "https://example.com", "timeout": 10000]))
        #expect(navigate.toolName == "navigate_page")
        #expect(navigate.arguments["type"] as? String == "url")
        #expect(navigate.arguments["url"] as? String == "https://example.com")
        #expect(navigate.arguments["timeout"] as? Int == 10000)

        let network = try BrowserMCPCallMapper.map(
            action: .network,
            arguments: ToolArguments(raw: ["request_id": 42]))
        #expect(network.toolName == "get_network_request")
        #expect(network.arguments["reqid"] as? Int == 42)

        let trace = try BrowserMCPCallMapper.map(
            action: .performanceTrace,
            arguments: ToolArguments(raw: ["trace_action": "start", "reload": false, "auto_stop": true]))
        #expect(trace.toolName == "performance_start_trace")
        #expect(trace.arguments["reload"] as? Bool == false)
        #expect(trace.arguments["autoStop"] as? Bool == true)
    }

    @Test
    func `Browser tool status includes permission instructions when disconnected`() async throws {
        let client = MockBrowserMCPClient(status: BrowserMCPStatus(
            isConnected: false,
            toolCount: 0,
            detectedBrowsers: []))
        let tool = BrowserTool(client: client)

        let response = try await tool.execute(arguments: ToolArguments(raw: ["action": "status"]))

        #expect(response.isError == false)
        let text = Self.text(from: response)
        #expect(text.contains("Connected: no"))
        #expect(text.contains("chrome://inspect/#remote-debugging"))
        #expect(text.contains("remote debugging permission prompt"))
    }

    @Test
    func `Browser tool connect and mapped execute use client`() async throws {
        let client = MockBrowserMCPClient(status: BrowserMCPStatus(
            isConnected: true,
            toolCount: 31,
            detectedBrowsers: []))
        let tool = BrowserTool(client: client)

        let connect = try await tool.execute(arguments: ToolArguments(raw: [
            "action": "connect",
            "channel": "canary",
        ]))
        #expect(connect.isError == false)
        #expect(client.connectedChannels == [.canary])

        let click = try await tool.execute(arguments: ToolArguments(raw: [
            "action": "click",
            "uid": "7_1",
        ]))
        #expect(click.isError == false)
        #expect(client.executedTools.last?.toolName == "click")
        #expect(client.executedTools.last?.arguments["uid"] as? String == "7_1")
        #expect(client.executedTools.last?.channel == nil)
    }

    @Test
    func `Browser tool forwards channel for first mapped execute`() async throws {
        let client = MockBrowserMCPClient(status: BrowserMCPStatus(
            isConnected: true,
            toolCount: 31,
            detectedBrowsers: []))
        let tool = BrowserTool(client: client)

        let snapshot = try await tool.execute(arguments: ToolArguments(raw: [
            "action": "snapshot",
            "channel": "canary",
        ]))

        #expect(snapshot.isError == false)
        #expect(client.executedTools.last?.toolName == "take_snapshot")
        #expect(client.executedTools.last?.channel == .canary)
    }

    @Test
    func `Browser tool uses browser client from context`() async throws {
        let client = MockBrowserMCPClient(status: BrowserMCPStatus(
            isConnected: true,
            toolCount: 1,
            detectedBrowsers: []))
        let services = PeekabooServices()
        let context = MCPToolContext(
            automation: services.automation,
            menu: services.menu,
            windows: services.windows,
            applications: services.applications,
            dialogs: services.dialogs,
            dock: services.dock,
            screenCapture: services.screenCapture,
            desktopObservation: services.desktopObservation,
            snapshots: services.snapshots,
            screens: services.screens,
            agent: nil,
            permissions: services.permissions,
            clipboard: services.clipboard,
            browser: client)
        let tool = BrowserTool(context: context)

        _ = try await tool.execute(arguments: ToolArguments(raw: [
            "action": "list_pages",
        ]))

        #expect(client.executedTools.last?.toolName == "list_pages")
    }

    private static func text(from response: ToolResponse) -> String {
        guard case let .text(text: text, annotations: _, _meta: _) = response.content.first else {
            return ""
        }
        return text
    }
}

@MainActor
private final class MockBrowserMCPClient: BrowserMCPClientProviding, @unchecked Sendable {
    struct ExecutedTool {
        let toolName: String
        let arguments: [String: Any]
        let channel: BrowserMCPChannel?
    }

    var status: BrowserMCPStatus
    var connectedChannels: [BrowserMCPChannel?] = []
    var disconnected = false
    var executedTools: [ExecutedTool] = []

    init(status: BrowserMCPStatus) {
        self.status = status
    }

    func status(channel: BrowserMCPChannel?) async -> BrowserMCPStatus {
        self.status
    }

    func connect(channel: BrowserMCPChannel?) async throws -> BrowserMCPStatus {
        self.connectedChannels.append(channel)
        return self.status
    }

    func disconnect() async {
        self.disconnected = true
    }

    func execute(
        toolName: String,
        arguments: [String: Any],
        channel: BrowserMCPChannel?) async throws -> ToolResponse
    {
        self.executedTools.append(ExecutedTool(toolName: toolName, arguments: arguments, channel: channel))
        return ToolResponse.text("called \(toolName)")
    }
}
