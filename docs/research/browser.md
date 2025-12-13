---
summary: 'Notes on DOM/JavaScript automation options for existing browser windows.'
read_when:
  - 'designing Peekaboo browser automation features'
  - 'evaluating DOM access strategies beyond AX'
---

# Browser Automation Research

## Goals
- Let agents inspect and mutate live DOM trees inside already-running browser tabs without relaunching those apps.
- Keep Peekaboo’s AX-based tools and any DOM/JS hooks in sync so clicks/typing can follow DOM-driven prep work.

## Chromium / Chrome
- You can only attach Playwright (or any CDP client) to an existing Chromium tab if the browser exposed a debugging endpoint at launch (`--remote-debugging-port=<port>`). Chrome 136+ requires pairing that flag with a non-default profile (`--user-data-dir=/tmp/pb-cdp-profile`) or the port is ignored.
- Once a CDP endpoint is live, `playwright.chromium.connectOverCDP()` (or Puppeteer / chrome-remote-interface) can list existing contexts/pages and run `Runtime.evaluate`, `DOM.querySelector`, etc., on the active tab. Plan: wrap that flow in a new `BrowserAutomationService` so Peekaboo agents call `browser js --app "Google Chrome" --snapshot <id>`.
- CLI idea: `polter peekaboo browser ensure-debug-port --app "Google Chrome"` relaunches Chrome via Poltergeist with the required flags, persists the assigned port, and returns it through Peekaboo services.

## Safari / WebKit
- Safari only permits remote JS via WebDriver. Users must enable Develop ▸ Allow Remote Automation, then `safaridriver --enable`. After that, Playwright (or our own WebDriver client) can target manually opened windows, but only through the dedicated automation session. Need to capture the entitlement status in diagnostics so agents surface actionable fixes when attachment fails.

## Lightweight DOM access
- For manual or prototype flows, DevTools Console + Snippets let users run arbitrary JS directly in the tab; wrapping those snippets into a DevTools extension (via `chrome.devtools.inspectedWindow.eval` or MV3 `chrome.scripting.executeScript`) provides a minimal injection path without Playwright.
- A production-grade Peekaboo integration should still lean on CDP/WebDriver so agents can automate without keeping DevTools open, but snippets/extensions are useful fallback guidance for humans.

## Playwright CLI Touchpoints
- `npx playwright test` with filters (`--project`, `-g`, `--headed`, `--debug`, `--ui`, `--trace retain-on-failure`) covers most automation launch cases.
- `npx playwright codegen <url>` generates selector-aware scripts and can save storage state for reuse. Ideal for seeding canonical DOM interaction recipes we later replay through Peekaboo’s browser service.
- `npx playwright install|install-deps` keeps bundled browsers in sync; document this so Peekaboo’s CI builders can provision CDP/WebDriver targets consistently.

## Open Questions / Next Steps
1. Prototype a Swift-based CDP session manager (one per browser window) and confirm we can map DOM node bounds back to AX nodes for hit-testing.
2. Decide whether Safari support ships simultaneously or later—WebDriver introduces different lifecycle semantics than CDP.
3. Extend `PeekabooAgentService` with MCP tools (`RunBrowserJavaScript`, `QueryBrowserDOM`) and update the system prompt so agents know when to fall back from AX to DOM.
