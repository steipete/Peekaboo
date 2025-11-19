# Security & Tool Hardening

Peekaboo ships powerful automation tools (clicking, typing, shell, window management, etc.). You can now constrain what the agent and MCP server expose.

## How to disable tools

- **One-off via env (highest precedence for allow list)**  
  - `PEEKABOO_ALLOW_TOOLS="see,click"` – only these tools are exposed.  
  - `PEEKABOO_DISABLE_TOOLS="shell,menu_click"` – always removed, combined with config `deny`.
- **Persistent config (`~/.peekaboo/config.json`)**  
  ```jsonc
  {
    "tools": {
      "allow": ["see", "click", "type"],
      "deny": ["shell", "window"]
    }
  }
  ```
  Env `ALLOW` replaces the config allow list; env `DISABLE` is additive with config `deny`. Deny always wins when a tool appears in both lists. Names are case-insensitive; `kebab-case` or `snake_case` both work.

Filters apply everywhere tools are surfaced: CLI `peekaboo tools`, the agent toolset, the MCP server’s tool registry, and external MCP servers registered through Peekaboo.

## Risk by tool category

- **Critical / high risk** – should usually be disabled in untrusted contexts  
  - `shell`: can run arbitrary commands; disable unless you fully trust the model and prompts.
  - `dialog_click`, `dialog_input`: can confirm destructive dialogs.
- **Medium risk** – can manipulate apps or data  
  - `click`, `type`, `press`, `scroll`, `swipe`, `drag`, `move`, `hotkey`: can trigger actions in foreground apps.  
  - `window`, `app`, `menu_click`, `dock_launch`, `space`: can close apps, move windows, switch spaces.  
  - `permissions`: can prompt/alter macOS permissions flow; disable for locked-down sessions.  
  - `mcp_agent`: can cascade into other tools via MCP.
- **Low risk / observational**  
  - `see`, `screenshot`, `list_apps`, `list_windows`, `list_screens`, `list_menus`: read-only discovery and capture.  
  - `image`, `analyze`, `sleep`, `done`, `need_info`: informational or control-plane only.

### Recommendations

- In production or shared machines: start with `PEEKABOO_ALLOW_TOOLS="see,click,type"` and add more only as required.  
- When connecting to external MCP servers (GitHub, Jira, custom tools), pair the allow list with denies for any server-prefixed tools you do not trust.  
- Document your chosen policy in team runbooks so other operators apply the same filters.
