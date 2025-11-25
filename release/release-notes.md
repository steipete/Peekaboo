## Installation

### Homebrew (Recommended)
```bash
brew tap steipete/peekaboo
brew install peekaboo
```

### Direct Download
```bash
curl -L https://github.com/steipete/peekaboo/releases/download/v3.0.0-beta1/peekaboo-macos-universal.tar.gz | tar xz
sudo mv peekaboo-macos-universal/peekaboo /usr/local/bin/
```

### npm (includes MCP server)
```bash
npm install -g @steipete/peekaboo
```

## What's New

- Native agent flows and full CLI surface for automation: `see`, `click`, `type`, `press`, `scroll`, `hotkey`, `swipe`, `drag`, `window`, `app`, `menu`, `space`, `dialog`, and more now ship in the Swift CLI with multi-screen capture and session-aware follow-ups.
- Peekaboo runs as an MCP server by default (npx @steipete/peekaboo-mcp) and bundles the Chrome DevTools MCP so assistants can mix native Mac tools with browser/GitHub/filesystem tools in a single session.
- AI defaults upgraded to GPT-5.1 family with refreshed model catalog (Gemini 2.5, Grok 4-fast, Claude 4.5); provider config respects env overrides and includes the `tk-config` helper.
- Retina captures (`peekaboo image --retina`) preserve native HiDPI scale, and `see --json-output` now returns richer metadata (`description`, `role_description`, `help`) for every UI element.
- Developer QoL: strict ordering in `tools` output, automation tests launch the freshly built binary, and docs/testing playbooks reflect the safe vs. automation suite split.

## Full Changelog
- Full details: https://github.com/steipete/Peekaboo/blob/main/CHANGELOG.md#300-beta1---2025-11-25

## Checksums

```
76a87266cfdc28b03f6eafb750e7b46a38b0d79f203d4f60b42421c4d3f58c36  peekaboo-macos-universal.tar.gz
62919e01f89d7e54aa654e80a635679fceba8b0fd389a7464f444f5f78f43762  steipete-peekaboo-mcp-3.0.0-beta1.tgz
```
