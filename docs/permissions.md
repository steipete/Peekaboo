---
summary: 'Grant required macOS permissions and understand performance trade-offs for Peekaboo.'
read_when:
  - 'Peekaboo cannot capture screens or focus windows'
  - 'tuning capture performance or troubleshooting permission dialogs'
---

# Permissions & Performance

## Requirements

- **macOS 15.0+ (Sequoia)** – core automation APIs depend on Sequoia.
- **Screen Recording (required)** – enables CGWindow capture and multi-app automation.
- **Accessibility (recommended)** – improves window focus, menu interaction, and dialog control.
- **Event Synthesizing (optional)** – enables `hotkey --focus-background` to post keyboard events to a target process without activating it.

## Granting Permissions

1. **Screen Recording**
   - System Settings → Privacy & Security → Screen & System Audio Recording.
   - Enable Terminal, your editor, or whatever shell runs `peekaboo`.
   - Benefit: fast CGWindow enumeration and background captures.

2. **Accessibility**
   - System Settings → Privacy & Security → Accessibility.
   - Enable the same terminals/IDEs so Peekaboo can send clicks/keystrokes reliably.

3. **Event Synthesizing**
   - Run `peekaboo permissions request-event-synthesizing`.
   - By default this requests access for the selected Peekaboo Bridge host, which is the process that sends background hotkeys. Add `--no-remote` to request access for the local CLI process instead.
   - If needed, enable Peekaboo in System Settings → Privacy & Security → Accessibility.
   - Benefit: process-targeted background hotkeys without focus stealing.

4. **Check Permissions**
   ```bash
   peekaboo permissions status    # Check current permission status
   peekaboo permissions grant     # Show grant instructions
   ```

## Performance Tips

- **Hybrid enumeration** – with Screen Recording enabled, Peekaboo prefers the CGWindowList APIs and falls back to AX only when necessary.
- **Built-in timeouts** – window/menu operations have ~2 s default timeouts to avoid hangs; adjust via CLI options if needed.
- **Parallel processing** – when both permissions are enabled, window queries and captures stream concurrently.

If automation feels sluggish, confirm permissions, then re-run with `--verbose` to inspect timings.
