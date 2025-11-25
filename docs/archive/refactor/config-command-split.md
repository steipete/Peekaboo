---
summary: 'ConfigCommand split plan (Nov 17, 2025)'
read_when:
  - 'refactoring config CLI commands'
  - 'debugging ConfigCommand structure or runtime wiring'
---

## ConfigCommand Split Plan (Nov 17, 2025)

- Add execution tests per subcommand: run against temp config/credentials paths, assert file writes, JSON output fields, and exit codes; cover add/list/remove/test/models flows and edit/validate happy/sad paths.
- Unify error/output surface: centralize codes/messages in a helper so JSON/text stay consistent and duplication drops across subcommands.
- Strengthen validation: reject provider base URLs without scheme/host, normalize headers (trim, dedupe, lowercase keys), and ensure apiKey/baseUrl are non-empty.
- Safer edit workflow: capture nonzero editor exits with stderr surfaced; add a `--print-path` dry run for automation that only prints the file path.
- Reduce repeated env lookups: shared helper for `$EDITOR`, config/credentials paths, and default save locations to cut per-command boilerplate.
- Smarter model discovery: add timeout + error classification (auth/network/server) and optional `--save` to persist discovered models back into config.
- Dry-run support for provider mutations: `--dry-run` on add/remove to show planned changes without writing files.
- CLI help cleanup: tighten discussion blocks, keep 80-col-friendly examples, and align wording across subcommands.
- Config schema guard: validate provider structs against a lightweight schema before writing; refuse partial/empty provider definitions.
