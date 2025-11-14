---
summary: 'Work with macOS status items via peekaboo menubar'
read_when:
  - 'clicking Wi-Fi/Bluetooth/battery icons from automation flows'
  - 'enumerating third-party status items with indices for later use'
---

# `peekaboo menubar`

`menubar` is a lightweight helper for macOS status items (a.k.a. menu bar extras). It talks directly to `MenuServiceBridge` so you can list every icon with its index or click one by title/index. Use the `menu` command for traditional application menus; this command is strictly for the right-hand side of the menu bar.

## Actions
| Positional action | Description |
| --- | --- |
| `list` | Prints every visible status item with its index. `--json-output` emits the same data plus bundle IDs and AX identifiers. |
| `click` | Clicks an item by name (case-insensitive fuzzy match) or via `--index <n>`. |

## Key options
| Flag | Description |
| --- | --- |
| `[itemName]` | Optional positional argument passed to `click`. |
| `--index <n>` | Target by numeric index (matches the ordering from `menubar list`). |
| Global flags | `--json-output` returns structured payloads; `--verbose` adds descriptions when listing. |

## Implementation notes
- The command name is `menubar` (no hyphen). Commander enforces `list`/`click` as the only valid actions.
- Listing uses `MenuServiceBridge.listMenuBarItems`, and verbose mode prints extra diagnostics (owner name, hidden state). JSON mode always includes the raw title, bundle ID, owner name, identifier, visibility, and description.
- Clicking resolves either `--index` or item text (case-insensitive). When an item isn’t found, text mode prints troubleshooting hints; JSON mode surfaces `MENU_ITEM_NOT_FOUND`.
- Coordinate data (if available) is recorded in the click result so you can correlate where on screen the interaction happened.

## Examples
```bash
# List every status item with indices
polter peekaboo -- menubar list

# Click the Wi-Fi icon by name
polter peekaboo -- menubar click "Wi-Fi"

# Click the third item regardless of name and capture JSON output
polter peekaboo -- menubar click --index 3 --json-output
```
