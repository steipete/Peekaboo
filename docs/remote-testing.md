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
- **Privacy permissions**: macOS only surfaces Accessibility / Screen Recording prompts in the GUI session. If you skip this step when driving tests over SSH, the CLI is denied access and the suite hangs. See [Granting privacy permissions](#granting-privacy-permissions-required-for-automation).
- **Privacy permissions**: macOS only shows Accessibility / Screen Recording prompts in the foreground GUI session. If you run the tests over SSH before granting them, the prompts never appear and the CLI hangs. See *Granting privacy permissions* below.

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

If you just want the CLI automation target (without local UI interaction), the existing script still works:

```bash
ssh steipete@peters-virtual-machine \
  'cd ~/Projects/peekaboo/Apps/CLI && PEEKABOO_INCLUDE_AUTOMATION_TESTS=true swift test'
```

For **full local automation** (UI-driven cases that expect a real display) we added a convenience script to `package.json`. It builds the CLI, points tests at the actual binary, and sets the right env vars:

```bash
pnpm run test:automation:local
```

This must be executed either:

- From an interactive Terminal on the VM (preferred), or
- Over SSH after privacy permissions have been granted and you’ve started a tmux session to keep the job alive.

`pnpm run test:automation:local` writes logs to `~/Projects/peekaboo/logs/automation-<timestamp>.log`. Tail the file while it runs to watch progress.

Warnings & learnings:
- The automation suite is heavy and may hang the VirtualBuddy UI if permissions are missing; watch the log for stalled commands.
- Running inside tmux (`brew install tmux`) is recommended so a frozen SSH session doesn’t kill the run.
- Grant Accessibility/Screen Recording before launching the script; otherwise macOS silently denies UI automation.

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

### Granting privacy permissions (required for automation)

macOS’ Transparency, Consent, and Control (TCC) framework **never** displays prompts to headless sessions. Launching automation over SSH without first approving the binaries leads to immediate hangs because helper processes (e.g. `swift-run peekaboo …`) are denied Accessibility / Screen Recording access. Fix:

1. Connect via Screen Sharing or VirtualBuddy and log in as the test user.
2. Open **System Settings → Privacy & Security** and visit **Accessibility**, **Screen Recording**, and **Automation** (optionally **Full Disk Access**).
3. Add and enable these executables (update paths if SwiftPM rebuilds into a new folder):
   ```
   ~/Projects/peekaboo/Apps/CLI/.build/arm64-apple-macosx/debug/peekaboo
   ~/Projects/peekaboo/Apps/CLI/.build/arm64-apple-macosx/debug/peekabooPackageTests.xctest/Contents/MacOS/peekabooPackageTests
   /Applications/Xcode.app/Contents/Developer/usr/bin/swift
   /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
   ```
4. Relaunch the automation suite; prompts will not reappear once these are approved.

> There is no supported way to approve these prompts purely over SSH. If GUI access is impossible, pre-approve via an MDM/PPPC payload or script the System Settings UI while logged in locally.

### Granting privacy permissions (required for automation)

macOS’ Transparency, Consent, and Control (TCC) framework **never** displays prompts to headless sessions. Launching the automation suite over SSH without first approving the binaries leads to immediate hangs because helper processes (e.g. `swift-run peekaboo …`) are denied Accessibility / Screen Recording access. The fix must be performed in the VM’s GUI:

1. Connect via Screen Sharing or VirtualBuddy and log in as the test user.
2. Open **System Settings → Privacy & Security** and visit **Accessibility**, **Screen Recording**, and **Automation** (optionally **Full Disk Access** if needed).
3. Add and enable these executables (update paths if SwiftPM rebuilds into a new folder):
   ```
   ~/Projects/peekaboo/Apps/CLI/.build/arm64-apple-macosx/debug/peekaboo
   ~/Projects/peekaboo/Apps/CLI/.build/arm64-apple-macosx/debug/peekabooPackageTests.xctest/Contents/MacOS/peekabooPackageTests
   /Applications/Xcode.app/Contents/Developer/usr/bin/swift
   /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
   ```
4. Relaunch the automation suite from SSH once the checkboxes are enabled; no prompts will reappear.

> There is no supported way to approve these prompts over plain SSH. If GUI access is impossible, pre-approve the binaries via an MDM/PPPC profile or script the System Settings UI inside a logged-in session.
