---
summary: 'How Peekaboo generates shell completions from Commander metadata'
read_when:
  - 'touching peekaboo completions or shell setup docs'
  - 'adding new commands/flags and expecting completions to update automatically'
---

# Completion architecture

Peekaboo intentionally generates shell completions from the same Commander
descriptor tree that powers CLI help, `peekaboo learn`, and runtime parsing.
That keeps completions on the same single source of truth as the rest of the
CLI surface.

## Ecosystem choices

For new Swift CLIs, Apple’s Swift Argument Parser is still the best
off-the-shelf option because it can generate bash/zsh/fish scripts directly.
Peekaboo does **not** use Argument Parser anymore, though—we migrated to the
custom `Commander` framework so runtime binding, help rendering, and descriptor
generation stay under our control.

We also do **not** parse Swift source files with SwiftSyntax for completions.
That would introduce a second metadata pipeline and drift risk. Commander
already exposes the normalized command tree we need at runtime, including
subcommands, option groups, aliases, and injected runtime flags.

## Source of truth

`CompletionScriptDocument.make(descriptors:)` consumes
`CommanderRegistryBuilder.buildDescriptors()` and normalizes it into:

- command paths
- argument metadata
- option / flag spellings (including aliases)
- curated value choices for known arguments like `completions [shell]`

Every shell renderer consumes that same document.

## Renderer design

The current production flow is:

1. `CompletionsCommand` resolves the target shell (`zsh`, `bash`, `fish`, or a full shell path like `/bin/zsh`).
2. `CompletionScriptDocument` builds a shell-agnostic command tree from Commander descriptors.
3. `CompletionScriptRenderer` renders one of three shell adapters:
   - `BashCompletionRenderer`
   - `ZshCompletionRenderer`
   - `FishCompletionRenderer`
4. Each adapter emits small shell helper functions that query the shared
   completion tables for:
   - subcommands
   - options / flags
   - known positional-value suggestions

The shell-specific code is intentionally thin; the command tree and completion
catalog live in Swift.

## Extending completions

When adding a new command or option:

1. Register/update the command’s `CommandDescription`.
2. Publish the right `CommanderSignatureProviding` metadata (or property-wrapper metadata).
3. If the command has a curated set of positional or option values worth
   completing, add them to `CompletionValueCatalog`.
4. Update docs if the new command changes user-facing setup guidance.

If you find yourself editing per-shell command names or flags directly, you are
probably bypassing the SSOT layer.
