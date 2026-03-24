---
summary: 'Agent skill for Peekaboo CLI automation'
read_when:
  - Setting up Peekaboo with AI agents
  - Installing the peekaboo-cli skill
---

# Agent Skill for Peekaboo

Peekaboo provides a skill file that enables AI agents to control macOS desktop automation through natural language commands. Works with Claude Code, OpenClaw, and other agents that support the skill format.

## What is a Skill?

A skill is a markdown file that teaches an AI agent how to use a tool. When you install the `peekaboo-cli` skill, the agent gains the ability to:

- Capture screenshots and analyze UI elements
- Click buttons, type text, and press keys
- Manage windows and applications
- Navigate menus and control the dock
- Perform complex automation workflows

## Installation

### Claude Code

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Copy the skill directory
cp -r skills/peekaboo-cli ~/.claude/skills/
```

### OpenClaw

```bash
# Copy to OpenClaw skills directory
cp -r skills/peekaboo-cli ~/.openclaw/skills/
```

### Other Agents

Refer to your agent's documentation for the skills directory location. Copy the entire `skills/peekaboo-cli` folder to that location.

## Prerequisites

Before using the skill, ensure:

1. **Peekaboo CLI is installed**:
   ```bash
   brew install steipete/tap/peekaboo
   ```

2. **Permissions are granted**:
   ```bash
   peekaboo permissions status
   peekaboo permissions grant  # if needed
   ```

## Usage

Once installed, simply ask your agent to perform automation tasks:

```
"Take a screenshot of the current window"
"Click the Submit button in Safari"
"Open Notes and create a new note with 'Hello World'"
"List all running applications"
```

The agent will use the Peekaboo CLI to execute these commands.

## Skill vs MCP Server

Peekaboo offers two integration options:

| Feature | Skill | MCP Server |
|---------|-------|------------|
| Setup complexity | Simple (copy files) | Moderate (config) |
| Direct tool access | CLI commands | Structured tools |
| Best for | CLI workflows | Complex integrations |

The skill is recommended for most agent users. Use the MCP server if you need:
- Structured JSON schemas
- Multiple MCP clients
- Direct tool invocation

## Troubleshooting

### Skill not loading
- Verify the skill directory is in the correct location
- Restart your agent after installation

### Permission errors
```bash
peekaboo permissions status
```

### Element not found
Ask the agent to re-capture the UI first:
```
"Capture the current UI and find the login button"
```

## Files

- `skills/peekaboo-cli/SKILL.md` - The skill definition
- `skills/peekaboo-cli/references/*.md` - Detailed command documentation

## References

- [Peekaboo GitHub](https://github.com/steipete/Peekaboo)
- [Command Reference](../docs/commands/README.md)
