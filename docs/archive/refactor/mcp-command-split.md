---
summary: 'MCPCommand split notes (Nov 17, 2025)'
read_when:
  - 'refactoring MCP CLI commands or helpers'
  - 'aligning MCP subcommand formatting/error handling'
---

## MCPCommand Split Notes (Nov 17, 2025)
_Status: Archived · Focus: decomposing MCPCommand and normalizing formatting/errors._

- Broke the 1.2K-line `MCPCommand.swift` into per-subcommand files plus small helpers (`MCPDefaults`, `MCPCallTypes`, `MCPCallFormatter`, `MCPArgumentParsing`, `MCPClientManaging`) to localize responsibilities and cut duplication.
- Behavior remains the same; the next improvement should be introducing an `MCPClientService` facade (wrapping `TachikomaMCPClientManager`) and a shared `MCPContext` to eliminate leftover `RuntimeStorage` boilerplate and make mocking straightforward.
- Consolidate output rendering: move List/Info JSON + text formatting into the formatter so field naming/order stays consistent, and decide whether stderr/os_log suppression stays or moves into a single helper.
- Normalize error handling across subcommands with a shared error type mapping to `ErrorCode` (today only Call uses `CallError`), and reuse key/value + JSON parsing helpers everywhere.
- Testing gaps: add unit tests for argument parsing, call payload serialization, and list/info formatting with a mock client service; run `./runner swift build` plus the CLI smoke tests once added.
