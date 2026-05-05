---
summary: 'Install and maintain the thin Peekaboo CLI agent skill.'
read_when:
  - 'setting up Peekaboo with AI agents'
  - 'updating the peekaboo-cli skill'
---

# Agent Skill for Peekaboo

The `peekaboo-cli` skill teaches agents when and how to call the installed Peekaboo CLI for macOS automation. It intentionally stays thin: agents should use live CLI help and canonical docs instead of a copied command reference that can drift.

## Install

Copy the skill directory into your agent's skills folder:

```bash
# Claude Code
mkdir -p ~/.claude/skills
cp -r skills/peekaboo-cli ~/.claude/skills/

# OpenClaw
mkdir -p ~/.openclaw/skills
cp -r skills/peekaboo-cli ~/.openclaw/skills/
```

Restart the agent after installing or updating the skill.

## Prerequisites

Install Peekaboo and grant macOS permissions:

```bash
brew install steipete/tap/peekaboo
peekaboo permissions status
peekaboo permissions grant
```

Agents should also use `peekaboo learn`, `peekaboo tools`, and `peekaboo <command> --help` for the current command surface.

## Canonical Docs

- Skill file: `skills/peekaboo-cli/SKILL.md`
- Command index: `docs/commands/README.md`
- Command pages: `docs/commands/*.md`
- Permissions: `docs/permissions.md`
- Subprocess/OpenClaw integration: `docs/integrations/subprocess.md`

## Maintenance Rule

Do not add generated per-command reference files to the skill. Update Commander metadata, `peekaboo learn`, or `docs/commands/*` instead.
