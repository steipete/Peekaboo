---
summary: 'MCP meta fields returned by the capture tool'
---

# MCP meta fields for `capture`

The `capture` MCP tool returns text plus meta entries that mirror `CaptureResult`.

## Meta keys

- `frames` (array<string>): absolute paths to kept PNG frames
- `contact` (string): absolute path to `contact.png`
- `metadata` (string): absolute path to `metadata.json`
- `diff_algorithm` (string)
- `contact_columns`, `contact_rows`, `contact_thumb_size`
- `contact_sampled_indexes` (array<string>): sampled frame indexes used in contact sheet

## Notes

- Paths are absolute in MCP responses.
- `capture` replaces the old `watch` tool.
