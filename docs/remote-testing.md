## Remote Testing Playbook

This document captures the current workflow for running Peekaboo’s SwiftPM test targets on a remote macOS VM over SSH, plus the pitfalls we hit while bringing the VM online.

### 1. Prerequisites

- **Network access**: the VM must be reachable via Tailscale. Verify with `ping 100.64.183.103` (replace with your tailnet IP).
- **SSH key**: copy your workstation key to the VM (`~/.ssh/authorized_keys`, 600 permissions). All commands below assume you can run `ssh steipete@peters-virtual-machine`.
- **Toolchains**: the VM needs Xcode/Swift toolchains that bundle the Swift Testing framework. On the VirtualBuddy instance we set the command line tools explicitly:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app
  xcode-select -p  # confirm path is /Applications/Xcode.app/Contents/Developer
  ```
- **Homebrew (optional)**: installed via `curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash` so we can add tooling later (tmux, pnpm, etc.).

### 2. Sync the Repository

From the local checkout:
```bash
rsync -az --delete \
  --exclude '.build' --exclude 'DerivedData' --exclude '.DS_Store' \
  ./ steipete@peters-virtual-machine:Projects/peekaboo
```
This keeps the remote tree in lock-step with `main`, including submodules.

### 3. Running the “Safe” (Non-Automation) Test Set

```bash
ssh steipete@peters-virtual-machine \
  'cd ~/Projects/peekaboo/Apps/CLI && swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION'
```

Hints:
- The `-DPEEKABOO_SKIP_AUTOMATION` flag matches local CI defaults and compiles only `CoreCLITests`.
- With Swift 6.2 / Swift Testing we had to enable the feature in `Package.swift` via `.enableExperimentalFeature("SwiftTesting")`. Without that, the remote build dies with `no such module 'Testing'`.
- If you want a log, send output to a file (`… > /tmp/peekaboo-safe.log`).

### 4. Running the Full Automation Suite

```bash
ssh steipete@peters-virtual-machine \
  'cd ~/Projects/peekaboo/Apps/CLI && PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test'
```

Warnings & learnings:
- The automation suite is heavy and may hang the VirtualBuddy UI. The last run froze midway, so we aborted after ~12 minutes. Capture logs (`> /tmp/peekaboo-full.log`) before attempting.
- `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true` causes the test target to spawn the real CLI. Ensure the VM has accessibility permissions granted; otherwise tests will stall waiting for dialogs.
- Running inside tmux is recommended once tmux is installed (`brew install tmux`), so a frozen Terminal doesn’t kill the session. For now we ran the command straight because tmux wasn’t available at first.

### 5. Diagnosing the Remote Environment

- `xcode-select -p` confirms which command line tools SwiftPM uses.
- `swift --version` prints the Swift toolchain (currently Swift 6.2.1 on the VM).
- If you need a visual check, Peekaboo can ironically be pointed at the VirtualBuddy UI to screenshot status dialogs.

### 6. Known Issues & Follow-up

- **Automation freeze**: investigate why `swift test` stalls during automation runs in VirtualBuddy (possibly accessibility permissions or long-running UI automation).
- **Tooling gaps**: install tmux, pnpm, and poltergeist services on the VM for parity with the Mac Studio workflow.
- **Logs**: standardize capturing test output under `/tmp/peekaboo-*.log` so multiple operators can review results.

### Quick Checklist

1. `ssh steipete@peters-virtual-machine` works (authorized key + Tailscale).
2. `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`.
3. `rsync … ./ steipete@peters-virtual-machine:Projects/peekaboo`.
4. Safe suite: `swift test -Xswiftc -DPEEKABOO_SKIP_AUTOMATION`.
5. Automation suite (optional): `PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test` (watch for hangs).
6. Capture output for each run and file it in `/tmp` for later inspection.

Following this flow we successfully ran the non-automation tests remotely; automation still needs stabilization once the VM finishes freezing issues.
