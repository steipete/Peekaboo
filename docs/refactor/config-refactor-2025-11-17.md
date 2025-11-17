## Config refactor — 2025-11-17

Scope: bring Peekaboo/Tachikoma config UX in line with OpenAI/Codex + Anthropic Max OAuth, add live provider validation, clean up first-run guidance, and expand supported providers (OpenAI, Anthropic, Grok/xAI alias, Gemini) while keeping env-vars untouched.

Docs touched (update targets already completed)
- `docs/commands/config.md`: new surface for `config add` (validate + store), `config login` (OAuth), live validation/timeout flags, updated examples including grok/gemini.
- `docs/provider.md`: clarified built-ins, OAuth vs API key storage, env vs credentials, grok/xai alias, add/login examples.
- `docs/configuration.md`: precedence now includes OAuth tokens; new variables for GROK/XAI/GEMINI; explicit “env never copied”.
- `docs/cli-command-reference.md`: command list now includes `add`/`login`.
- `docs/oauth.md`: new file explaining OAuth flows, storage, refresh, beta headers, headless, revoke.

Reasoning highlights
- Avoid naggy init: show a status/next-steps table instead of per-provider prompts.
- Never persist env values; only user actions write credentials. Prevent phantom “none” entries.
- Prefer OAuth where available; fall back to API keys; keep backward compatibility.
- Validate immediately on add/show/init so users see “ready vs stored (failed)” without trial/error.
- Normalize Grok/xai to one code path and keep provider list small and clear.

Implementation plan (handoff-ready)
1) CLI surface
   - Add `config add <provider> <secret> [--timeout sec]` for openai|anthropic|grok(xai)|gemini.
   - Add `config login openai` (ChatGPT/Codex OAuth) and `config login anthropic` (Claude Pro/Max OAuth); no API key persisted.
   - `set-credential` remains as a legacy alias; help should point to `add`.

2) Validation layer
   - Shared validator with per-provider strategy and default 30s timeout (overridable on add/show/init).
   - OpenAI/Codex: GET /v1/models with bearer.
   - Anthropic: POST /v1/messages (tiny ping, e.g., model claude-3-haiku) or models list; include Max beta header when OAuth.
   - Grok/xai: GET https://api.x.ai/v1/models with bearer.
   - Gemini: GET https://generativelanguage.googleapis.com/v1beta/models?key=<key>.
   - Record lastValidation status + timestamp in credentials metadata (do not write env values).

3) Credential resolution order
   - env ➜ credentials (API key or OAuth tokens) ➜ config; never copy env into files.
   - Grok canonical ID `grok`; accept `xai` alias and env keys `GROK_API_KEY`, `X_AI_API_KEY`, `XAI_API_KEY`.

4) Runtime usage changes
   - Providers prefer OAuth tokens; refresh once per request if expired and update credentials; if missing/failed, fall back to API key.
   - Anthropic requests add beta header in OAuth mode.

5) init/show UX
   - Print provider table: source (env/credentials/oauth), last validation result, age.
   - If missing providers, show concise “Add one” block with `config add/login` commands; do not write placeholders.

6) Tests (increase coverage)
   - Unit: validator success/failure/timeout per provider; grok alias normalization; credential resolution priority.
   - Integration: mocked HTTP for add/show with --timeout; OAuth token refresh path (mock endpoints) for openai/anthropic; Anthropic beta header assertion.
   - CLI snapshot/golden tests for status table outputs (missing, env-only, cred-success, cred-fail).

7) Migration/compat
   - Continue honoring existing credentials keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, X_AI_API_KEY/XAI_API_KEY, GEMINI_API_KEY).
   - Do not modify `config.json`; credentials file is the only write target for secrets/tokens.

Open questions: none pending; user approved Swift-only helpers, no API-key persistence for OAuth, and status-first UX without prompt spam.
