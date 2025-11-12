import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Program Resolution (MCP + Window)")
struct CommanderBinderMCPWindowTests {
    @Test("Commander program resolves MCP serve options")
    @MainActor
    func commanderResolvesMcpServe() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "serve",
            "--transport", "http",
            "--port", "9090"
        ])
        let values = invocation.parsedValues
        #expect(values.options["transport"] == ["http"])
        #expect(values.options["port"] == ["9090"])
    }

    @Test("Commander program resolves MCP call options")
    @MainActor
    func commanderResolvesMcpCall() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "call",
            "claude-code",
            "--tool", "edit_file",
            "--args", #"{"path":"main.swift"}"#
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["claude-code"])
        #expect(values.options["tool"] == ["edit_file"])
        #expect(values.options["args"] == [#"{"path":"main.swift"}"#])
    }

    @Test("Commander program resolves MCP add options")
    @MainActor
    func commanderResolvesMcpAdd() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "add",
            "github",
            "-e", "API_KEY=xyz",
            "--transport", "stdio",
            "--description", "GitHub tools",
            "--disabled",
            "--",
            "npx",
            "-y",
            "@modelcontextprotocol/server-github"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["github", "npx", "-y", "@modelcontextprotocol/server-github"])
        #expect(values.options["env"] == ["API_KEY=xyz"])
        #expect(values.options["transport"] == ["stdio"])
        #expect(values.options["description"] == ["GitHub tools"])
        #expect(values.flags.contains("disabled"))
    }

    @Test("Commander program resolves MCP list flag")
    @MainActor
    func commanderResolvesMcpList() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "list",
            "--skip-health-check"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("skipHealthCheck"))
    }

    @Test("Commander program resolves window close options")
    @MainActor
    func commanderResolvesWindowClose() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "close",
            "--app", "Safari",
            "--window-title", "Inbox"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
    }

    @Test("Commander program resolves window move options")
    @MainActor
    func commanderResolvesWindowMove() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "move",
            "--app", "Notes",
            "--x", "120",
            "--y", "240"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Notes"])
        #expect(values.options["x"] == ["120"])
        #expect(values.options["y"] == ["240"])
    }

    @Test("Commander program resolves window focus options")
    @MainActor
    func commanderResolvesWindowFocus() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "focus",
            "--app", "Safari",
            "--window-title", "Inbox",
            "--space-switch",
            "--bring-to-current-space"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
        #expect(values.flags.contains("spaceSwitch"))
        #expect(values.flags.contains("bringToCurrentSpace"))
    }

    @Test("Commander program resolves app launch options")
    @MainActor
    func commanderResolvesAppLaunch() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "app",
            "launch",
            "\"Visual Studio Code\"",
            "--bundle-id", "com.microsoft.VSCode",
            "--wait-until-ready"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["\"Visual Studio Code\""])
        #expect(values.options["bundleId"] == ["com.microsoft.VSCode"])
        #expect(values.flags.contains("waitUntilReady"))
    }

    @Test("Commander program resolves app quit options")
    @MainActor
    func commanderResolvesAppQuit() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "app",
            "quit",
            "--all",
            "--except", "Finder,Terminal",
            "--force"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("all"))
        #expect(values.options["except"] == ["Finder,Terminal"])
        #expect(values.flags.contains("force"))
    }

    @Test("Commander program resolves menu click options")
    @MainActor
    func commanderResolvesMenuClick() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "menu",
            "click",
            "--app", "Safari",
            "--path", "File > New",
            "--no-auto-focus"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["path"] == ["File > New"])
        #expect(values.flags.contains("noAutoFocus"))
    }

    @Test("Commander program resolves permissions default subcommand")
    @MainActor
    func commanderResolvesPermissionsDefault() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "permissions",
            "--json-output"
        ])
        #expect(invocation.path == ["permissions", "status"])
        #expect(invocation.parsedValues.flags.contains("jsonOutput"))
    }

    @Test("Commander program resolves tools command options")
    @MainActor
    func commanderResolvesToolsCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "tools",
            "--native-only",
            "--include-disabled",
            "--no-sort",
            "--group-by-server",
            "--mcp",
            "github"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("nativeOnly"))
        #expect(values.flags.contains("includeDisabled"))
        #expect(values.flags.contains("noSort"))
        #expect(values.flags.contains("groupByServer"))
        #expect(values.options["mcp"] == ["github"])
    }
}
