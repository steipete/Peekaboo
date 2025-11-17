## Config refactor — 2025-11-17 (updated)

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
- Implement the above inside Tachikoma; add a Peekaboo shim that reuses it via profile directory.
- Add the test coverage once the refactor lands.

## Progress log (2025-11-17)
- Docs: updated provider/config/oauth references and clarified grok/xai aliasing.
- Tachikoma: new AuthManager (CredentialStore/Resolver, validators, OAuth PKCE) and providers (OpenAI/Anthropic) now resolve auth via AuthManager (bearer or API key). Grok env aliases normalized.
- Peekaboo CLI: refactored `config add/login/status` to delegate validation/OAuth/storage to Tachikoma AuthManager; `profileDirectoryName` forced to `.peekaboo` during CLI runs; legacy set-credential writes via AuthManager.
- Submodule updated: Tachikoma commit `d08e422` (auth centralization); main commit `24ad2458` wires Peekaboo CLI to Tachikoma.
- Remaining work: add status/validation CLI inside Tachikoma or reuse the shared logic for other hosts; add tests (validators, OAuth refresh, CLI snapshots); implement refresh persistence path in Tachikoma Configuration if desired.

## Next steps (for the refactor proper)
1) Build Tachikoma CredentialStore/Resolver + OAuthManager + validators; add Tachikoma CLI (`config add/login/show/init`).
2) Adjust providers to consume AuthToken; remove Peekaboo-local auth logic and just set `profileDirectoryName = ".peekaboo"`.
3) Update Peekaboo CLI to forward/alias Tachikoma commands (or shell out) instead of owning auth logic.
4) Add tests (unit + mock HTTP + CLI snapshots) as outlined above.
5) Re-run docs to ensure they match the final code paths.
