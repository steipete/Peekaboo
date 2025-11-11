import Commander

extension ToolsCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "mcp",
                    help: "Show tools from specific MCP server",
                    long: "mcp"
                ),
            ],
            flags: [
                .commandFlag(
                    "nativeOnly",
                    help: "Show only native Peekaboo tools",
                    long: "native-only"
                ),
                .commandFlag(
                    "mcpOnly",
                    help: "Show only external MCP tools",
                    long: "mcp-only"
                ),
                .commandFlag(
                    "includeDisabled",
                    help: "Include disabled servers in output",
                    long: "include-disabled"
                ),
                .commandFlag(
                    "noSort",
                    help: "Disable alphabetical sorting",
                    long: "no-sort"
                ),
                .commandFlag(
                    "groupByServer",
                    help: "Group external tools by server",
                    long: "group-by-server"
                ),
            ]
        )
    }
}
