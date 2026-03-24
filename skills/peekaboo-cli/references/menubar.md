---
summary: 'Work with macOS status items via peekaboo menubar'
---

# `peekaboo menubar`

`menubar` is a helper for macOS status items (menu bar extras).

## Actions

| Positional action | Description |
| --- | --- |
| `list` | Prints every visible status item with its index. |
| `click` | Clicks an item by name (case-insensitive fuzzy match) or via `--index <n>`. |

## Key options

| Flag | Description |
| --- | --- |
| `[itemName]` | Optional positional argument passed to `click`. |
| `--index <n>` | Target by numeric index. |
| `--verify` | After clicking, confirm a popover appeared. |

## Examples

```bash
# List every status item with indices
peekaboo menubar list

# Click the Wi-Fi icon by name
peekaboo menubar click "Wi-Fi"

# Click and verify the popover opened
peekaboo menubar click "Wi-Fi" --verify

# Click the third item regardless of name
peekaboo menubar click --index 3 --json-output
```
