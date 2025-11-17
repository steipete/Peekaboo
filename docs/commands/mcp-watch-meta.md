---
summary: 'MCP meta fields returned by the watch tool'
read_when:
  - 'documenting agent-facing watch responses'
---

# MCP meta fields for `watch`

The `watch` MCP tool returns a text response with meta containing:

- `frames`: array of frame paths
- `contact`: contact sheet path
- `metadata`: metadata.json path
- `diff_algorithm`: e.g. `fast` or `quality`
- `diff_scale`: e.g. `w256`
- `contact_columns`: contact sheet columns (string)
- `contact_rows`: contact sheet rows (string)
- `contact_sampled_indexes`: array of frame indexes included in the contact sheet (strings)
- `contact_thumb_size`: e.g. `200x200`

These mirror the `WatchCaptureResult` fields and allow agents to reason about grid layout and sampling without opening the files. Only string types are used in the meta map for compatibility with downstream consumers; paths remain absolute.
