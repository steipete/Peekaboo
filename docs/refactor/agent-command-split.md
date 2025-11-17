## AgentCommand Split Lessons (Nov 17, 2025)

- Trimmed `AgentCommand.swift` by extracting chat + audio flows and a `AgentChatLaunchPolicy` for clearer responsibilities and testing.
- Kept visibility wider than ideal to share helpers; future refactor should move UI helpers (`AgentChatUI`, delegates) and output factories into their own types instead of relaxing access control.
- Cancellation and bootstrap could be cleaner: replace `EscapeKeyMonitor` with cancellable task wrappers and wrap credential/logging checks in a reusable bootstrap helper.
- Add more tests: chat precondition failures (json/quiet/dry-run/no-cache/audio), audio task composition, and policy integration with `--chat` + task input combinations.
- Centralize user-facing strings (errors/help text) into a small messages helper to reduce duplication and ease tweaks.

### Additional follow-ups (post-refactor review)
- Restore the real TauTUI chat UI instead of the stub by moving `AgentChatUI/AgentChatEventDelegate` into their own file with proper imports (`AgentChatInput`, `ToolResult`, `ToolFormatterRegistry`) and revert to the richer rendering.
- Fix the sendable-capture warning in `runTauTUIChatLoop` by keeping session ids in an actor or local value passed into the task (no mutation of captured vars).
- Re-tighten visibility: expose narrow protocols (e.g., `AgentOutputFactory`, `AgentChatRunner`) so helpers stay `private` while remaining testable.
- Consolidate user-facing strings into an `AgentMessages` helper to avoid drift across chat/audio/precondition paths.
- Expand test coverage to hit `runInternal` glue (not just helper structs) once the UI is restored; re-run full CLI test suite instead of filtered subsets.
