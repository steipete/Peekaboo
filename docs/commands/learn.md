---
summary: 'Dump the full Peekaboo agent guide via peekaboo learn'
read_when:
  - 'needing the latest system prompt, tool catalog, and best practices in one blob'
  - 'building or QA-ing external agents that embed Peekaboo instructions'
---

# `peekaboo learn`

`peekaboo learn` prints the canonical “agent guide” that powers Peekaboo’s AI flows. It stitches together the generated system prompt, every tool definition from `ToolRegistry`, best-practice checklists, common workflows, and the full Commander signature table so other runtimes can stay in sync with the CLI release.

## What it emits
- **System instructions** straight from `AgentSystemPrompt.generate()`, including communication rules and safety guidance.
- **Tool catalog** grouped by category with each tool’s abstract, required/optional parameters, and JSON examples (if available).
- **Best practices + quick reference**: long-form guidance for automation patterns, then a condensed cheat sheet.
- **Commander section**: a programmatic dump of every CLI command’s positional arguments, options, and flags (built by `CommanderRegistryBuilder.buildCommandSummaries()`).

## Implementation notes
- The command is intentionally text-only—`--json-output` is ignored—so downstream systems should capture stdout if they want to cache the content.
- Everything runs on the main actor because it pulls live data from `ToolRegistry` and Commander; no stale handwritten docs are involved.
- Because it reuses the same builders the CLI uses at runtime, new commands/tools automatically show up here as soon as they land.

## Examples
```bash
# Save the full guide for another agent runtime
polter peekaboo -- learn > /tmp/peekaboo-guide.md

# Extract just the Commander signatures
polter peekaboo -- learn | awk '/^## Commander/,0'
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
