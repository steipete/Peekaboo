import Commander

extension MCPCommand.Serve: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "transport",
                    help: "Transport type (stdio, http, sse)",
                    long: "transport"
                ),
                .commandOption(
                    "port",
                    help: "Port for HTTP/SSE transport",
                    long: "port"
                ),
            ]
        )
    }
}

extension MCPCommand.Call: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "server", help: "MCP server to connect to", isOptional: false),
            ],
            options: [
                .commandOption(
                    "tool",
                    help: "Tool to call",
                    long: "tool"
                ),
                .commandOption(
                    "args",
                    help: "Tool arguments as JSON",
                    long: "args"
                ),
            ]
        )
    }
}

extension MCPCommand.List: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            flags: [
                .commandFlag(
                    "skipHealthCheck",
                    help: "Skip health checks (faster)",
                    long: "skip-health-check"
                ),
            ]
        )
    }
}

extension MCPCommand.Add: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name for the MCP server", isOptional: false),
                .make(label: "command", help: "Command and arguments to run the MCP server", isOptional: false),
            ],
            options: [
                OptionDefinition.make(
                    label: "env",
                    names: [.short("e"), .long("env")],
                    help: "Environment variables (key=value)",
                    parsing: .singleValue
                ),
                .commandOption(
                    "header",
                    help: "HTTP headers for HTTP/SSE (Key=Value)",
                    long: "header",
                    parsing: .upToNextOption
                ),
                .commandOption(
                    "timeout",
                    help: "Connection timeout in seconds",
                    long: "timeout"
                ),
                .commandOption(
                    "transport",
                    help: "Transport type (stdio, http, sse)",
                    long: "transport"
                ),
                .commandOption(
                    "description",
                    help: "Description of the server",
                    long: "description"
                ),
            ],
            flags: [
                .commandFlag(
                    "disabled",
                    help: "Disable the server after adding",
                    long: "disabled"
                ),
            ]
        )
    }
}

extension MCPCommand.Remove: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name of the MCP server to remove", isOptional: false),
            ],
            flags: [
                .commandFlag(
                    "force",
                    help: "Skip confirmation prompt",
                    long: "force"
                ),
            ]
        )
    }
}

extension MCPCommand.Test: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name of the MCP server to test", isOptional: false),
            ],
            options: [
                .commandOption(
                    "timeout",
                    help: "Connection timeout in seconds",
                    long: "timeout"
                ),
            ],
            flags: [
                .commandFlag(
                    "showTools",
                    help: "Show available tools",
                    long: "show-tools"
                ),
            ]
        )
    }
}

extension MCPCommand.Info: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name of the MCP server", isOptional: false),
            ]
        )
    }
}

extension MCPCommand.Enable: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name of the MCP server to enable", isOptional: false),
            ]
        )
    }
}

extension MCPCommand.Disable: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "name", help: "Name of the MCP server to disable", isOptional: false),
            ]
        )
    }
}

extension MCPCommand.Inspect: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(label: "server", help: "Server to inspect", isOptional: true),
            ]
        )
    }
}
