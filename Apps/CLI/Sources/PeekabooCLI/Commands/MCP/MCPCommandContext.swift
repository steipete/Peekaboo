//
//  MCPCommandContext.swift
//  PeekabooCLI
//

import Logging

/// Shared runtime container passed into MCP subcommands to avoid duplicating storage plumbing.
struct MCPCommandContext {
    let runtime: CommandRuntime
    let service: any MCPClientService

    var logger: Logger { self.runtime.logger }
    var wantsJSON: Bool { self.runtime.configuration.jsonOutput }
    var isVerbose: Bool { self.runtime.configuration.verbose }
}
