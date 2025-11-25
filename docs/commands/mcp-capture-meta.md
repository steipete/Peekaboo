---
summary: 'MCP meta fields returned by the capture tool (live + video)'
read_when:
  - 'documenting agent-facing capture responses'
---

# MCP meta fields for `capture`

The `capture` MCP tool (source = `live` or `video`) returns text plus meta entries that mirror `CaptureResult` so agents can reason about outputs without opening files.

## Meta keys
- `frames` (array<string>): absolute paths to kept PNG frames
- `contact` (string): absolute path to `contact.png`
- `metadata` (string): absolute path to `metadata.json`
- `diff_algorithm` (string)
- `diff_scale` (string, e.g., `w256`)
- `contact_columns` (string)
- `contact_rows` (string)
- `contact_thumb_size` (string: `WxH`)
- `contact_sampled_indexes` (array<string>): sampled frame indexes used in the contact sheet

Notes:
- Paths are absolute in MCP responses; `metadata.json` stores basenames for portability.
- `capture` replaces the old `watch` tool; a `watch` alias may exist internally for compatibility but is no longer documented.

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json-output` or `--verbose` to surface detailed errors.
