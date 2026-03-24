---
summary: 'Dump the full Peekaboo agent guide via peekaboo learn'
---

# `peekaboo learn`

`peekaboo learn` prints the canonical "agent guide" that powers Peekaboo's AI flows.

## What it emits

- System instructions from `AgentSystemPrompt.generate()`
- Tool catalog grouped by category
- Best practices + quick reference
- Commander signatures for every CLI command

## Examples

```bash
# Save the full guide
peekaboo learn > /tmp/peekaboo-guide.md

# Extract just the Commander signatures
peekaboo learn | awk '/^## Commander/,0'
```
