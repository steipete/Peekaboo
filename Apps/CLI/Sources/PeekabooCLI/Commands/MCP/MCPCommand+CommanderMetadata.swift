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
