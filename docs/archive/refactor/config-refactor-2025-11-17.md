---
summary: 'Config refactor notes (Nov 17, 2025)'
read_when:
  - 'continuing the config refactor'
  - 'debugging ConfigCommand behavior after Nov 2025 changes'
---

## Config refactor — 2025-11-17 (updated)
_Status: Archived · Focus: config CLI/runtime refactor checklist._

Scope: consolidate config/auth logic inside Tachikoma so hosts stay thin. Tachikoma owns credential resolution, storage, validation, OAuth (OpenAI/Codex + Anthropic Max), token refresh, and CLI UX. Hosts (Peekaboo, others) only set the profile directory (e.g., `.peekaboo`) or inject a custom credential provider.

Docs touched (update targets already completed)
- `docs/commands/config.md`: new surface for `config add` (validate + store), `config login` (OAuth), live validation/timeout flags, updated examples including grok/gemini.
- `docs/provider.md`: clarified built-ins, OAuth vs API key storage, env vs credentials, grok/xai alias, add/login examples.
- `docs/configuration.md`: precedence now includes OAuth tokens; new variables for GROK/XAI/GEMINI; explicit “env never copied”.
- `docs/cli-command-reference.md`: command list now includes `add`/`login`.
- `docs/oauth.md`: new file explaining OAuth flows, storage, refresh, beta headers, headless, revoke.

Reasoning highlights
- Single implementation in Tachikoma re-used by any host; Peekaboo becomes a thin shell.
- Env values are never copied; only explicit user actions write secrets/tokens. Missing providers are not persisted as “none.”
- OAuth preferred when available; API keys remain as fallback. Grok canonical ID `grok` with `xai` alias.
- Live validation/status avoid trial-and-error; no naggy init prompts.

Implementation plan (handoff-ready)
1) Tachikoma auth/config core
   - CredentialStore (file, chmod 600) + CredentialResolver (env ➜ creds ➜ config), alias support (grok/xai).
   - ProviderId metadata: supportsOAuth, credential keys, validation endpoint.
   - OAuthManager (PKCE, exchange, refresh) for openai/anthropic; store refresh/access/expiry (+ beta header for Anthropic).
   - Validators per provider with timeout (default 30s) and result metadata.

2) Provider runtime
   - OpenAI/Anthropic providers accept AuthToken (apiKey or bearer + optional beta). Prefer OAuth tokens; fallback to API key. Grok/Gemini remain API-key only.

3) Configuration resolution
   - TachikomaConfiguration loads credentials via resolver (profileDirectoryName overrideable); hosts may inject an in-memory credential provider to avoid disk.
   - Hosts can still push secrets directly if desired.

4) CLI (Tachikoma-owned)
   - `config add <provider> <secret> [--timeout]` (openai|anthropic|grok|gemini) with immediate validation.
   - `config login <provider>` (openai, anthropic) PKCE, optional no-browser; stores tokens, not API keys.
   - `config show/init` print status table with live validation; no per-provider prompts.

5) Host wiring (Peekaboo)
   - Set `TachikomaConfiguration.profileDirectoryName = ".peekaboo"`.
   - Re-export or shell to Tachikoma config commands for consistent UX.
   - Remove Peekaboo-local auth/validation logic; rely on Tachikoma resolver/refresh.

6) Tests to add
   - Unit: validator success/fail/timeout; alias normalization; credential precedence; OAuth refresh updates.
   - Integration/mock HTTP: login flows, refresh path, status table snapshots (missing/env/cred/oauth).
   - CLI snapshots for add/login/show/init outputs.

7) Migration/compat
   - Honor existing keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, GROK/XAI, GEMINI) and new token keys.
   - No env copying; no config.json writes for secrets.

Open items
- Finalize the Peekaboo-facing UX for `config init/show/add/login` using the Tachikoma AuthManager surface (today Peekaboo still owns legacy config verbs).
- Decide on canonical naming for xAI/Grok in user-facing docs (`provider id` stays `grok`, canonical env key is `X_AI_API_KEY`, aliases: `XAI_API_KEY`, `GROK_API_KEY`, string id `xai` now maps to Grok).
- Wire Peekaboo CLI to rely on the new Tachikoma `tachikoma config` binary (keep `tk-config` alias for back-compat) instead of owning prompts/status tables.
- Update migration tracker once the Peekaboo CLI wiring and docs are finished.

## Progress log
- 2025-11-18 (evening): All Tachikoma tests green after introducing the namespaced CLI entry point `tachikoma config …` (binary alias `tk-config`). Status/add/login/init now route through the shared AuthManager; test helpers isolate env per test and scrub per-profile credentials for missing-key assertions. OpenAI transcription tests explicitly pass their configs so keys are honored in mock mode.
- 2025-11-18 (afternoon): All Tachikoma tests now green. Fixed Azure OpenAI helper to use per-test URLSession and preserve api-version/api-key/bearer semantics; OpenAI Responses/chat mocks no longer conflict. Mock transcription now returns `"mock transcription"` with word timestamps. Environment isolation now scoped per test (no global unsets), ignore-env flag restored after each helper. Added GROK_API_KEY alias and `xai` string mapping; AuthManager setIgnoreEnvironment now returns previous state for scoped usage.
- 2025-11-17: AuthManager centralization (CredentialStore/Resolver, validators, OAuth PKCE) and provider wiring; docs refreshed for config/oauth/provider surfaces; profile dir override for Peekaboo set to `.peekaboo`; open issues listed above (now resolved).

Next steps (for the refactor proper)
1) Finish Peekaboo wiring: make `peekaboo config` call into Tachikoma AuthManager (or shell `tachikoma config`) and drop the legacy prompt logic; keep profile dir override `.peekaboo`.
2) Keep the xAI/Grok naming consistent in user-facing docs while accepting `grok`/`xai` plus `X_AI_API_KEY`/`XAI_API_KEY`/`GROK_API_KEY`.
3) Add CLI snapshot tests for `tachikoma config init/show/add/login` plus validator timeout cases; add OAuth refresh unit tests.
4) Update migration tracker once Peekaboo wiring lands and refresh docs for the new flow.
