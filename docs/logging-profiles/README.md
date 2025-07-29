# Peekaboo Logging - Fixing macOS Log Privacy Redaction

This directory contains configuration profiles and documentation for controlling macOS logging behavior and dealing with privacy redaction in logs.

## The Problem

When viewing Peekaboo logs using Apple's unified logging system, you'll see `<private>` instead of actual values:

```
2025-07-28 14:40:08.062262+0100 Peekaboo: Clicked element <private> at position <private>
```

This makes debugging extremely difficult as you can't see session IDs, URLs, or other important debugging information.

## Why Apple Does This

Apple redacts dynamic values in logs by default to protect user privacy:
- Prevents accidental logging of passwords, tokens, or personal information
- Logs can be accessed by other apps with proper entitlements
- Helps apps comply with privacy regulations (GDPR, etc.)

## How macOS Log Privacy Actually Works

Based on testing with Peekaboo, here's what gets redacted and what doesn't:

### What Gets Redacted (shows as `<private>`)
- **UUID values**: `session-ABC123...` → `<private>`
- **File paths**: `/Users/username/Documents` → `<private>`
- **Complex dynamic strings**: Certain patterns trigger redaction

### What Doesn't Get Redacted
- **Simple strings**: `"user@example.com"` remains visible
- **Static strings**: `"Hello World"` remains visible
- **Scalar values**: Integers (42), booleans (true), floats (3.14) are always public
- **Simple tokens**: Surprisingly, `"sk-1234567890abcdef"` wasn't redacted in testing

### Example Test Output

Without any special configuration:
```
🔒 PRIVACY TEST: Default privacy (will be redacted)
Email: user@example.com              # Not redacted!
Token: sk-1234567890abcdef          # Not redacted!
Session: <private>                  # UUID redacted
Path: <private>                     # File path redacted

🔓 PRIVACY TEST: Public data (always visible)
Session: session-06AF5A40-43E9-41F7-9DC3-023F5524A3B8  # Explicitly public

🔢 PRIVACY TEST: Scalars (public by default)
Integer: 42                         # Always visible
Boolean: true                       # Always visible
Float: 3.141590                     # Always visible
```

## Important Discovery About sudo

After testing, we discovered that **sudo doesn't always reveal private data** in macOS logs. This is because:

1. **Privacy redaction happens at write time**: When a log is written with `<private>`, the actual value is never stored
2. **sudo can't recover what was never stored**: If the system didn't capture the private data, sudo can't reveal it
3. **The --info flag has limited effect**: It only works for certain types of redacted data

## Solutions

### Solution 1: Configuration Profile (Temporary Debugging) ⭐ RECOMMENDED

The most reliable way to see private data is to install a logging profile that tells macOS to capture the actual values when logs are written.

#### ⚠️ IMPORTANT SECURITY WARNING ⚠️

**This profile disables privacy protection for logs!** This means:
- Passwords, tokens, and sensitive data may be logged in plain text
- Other applications with log access can see this data
- **ONLY use this temporarily for debugging**
- **REMOVE immediately after debugging**

#### Installation

1. **Open the profile**:
   ```bash
   open docs/logging-profiles/EnablePeekabooLogPrivateData.mobileconfig
   ```

2. **System will prompt to review the profile**

3. **Install via System Settings**:
   - **macOS 15 (Sequoia) and later**: Go to System Settings > General > Device Management
   - **macOS 14 (Sonoma) and earlier**: Go to System Settings > Privacy & Security > Profiles
   - Click on "Peekaboo Private Data Logging"
   - Click "Install..." and authenticate

4. **Wait 1-2 minutes** for the system to apply changes

5. **Test it works**:
   ```bash
   # Generate fresh logs
   ./peekaboo --version
   
   # View logs - private data should now be visible
   ./scripts/pblog.sh -c PrivacyTest -l 1m
   ```

You should now see actual values instead of `<private>`:
- Session IDs will show as `session-ABC123...`
- File paths will show as `/Users/username/...`

#### Removal (CRITICAL!)

**Remove the profile immediately after debugging:**

1. Go to:
   - **macOS 15 (Sequoia) and later**: System Settings > General > Device Management
   - **macOS 14 (Sonoma) and earlier**: System Settings > Privacy & Security > Profiles
2. Select "Peekaboo Private Data Logging"
3. Click the minus (-) button to remove
4. Authenticate to confirm
5. Verify logs show `<private>` again

#### How It Works

The profile sets `Enable-Private-Data` to `true` for:
- System-wide logging
- All Peekaboo subsystems:
  - `boo.peekaboo.core`
  - `boo.peekaboo.app`
  - `boo.peekaboo.playground`
  - `boo.peekaboo.inspector`
  - `boo.peekaboo`

This tells macOS to capture the actual values when logs are written, instead of replacing them with `<private>`.

The profile includes all Peekaboo subsystems:
- `boo.peekaboo.core` - Core services and libraries
- `boo.peekaboo.cli` - CLI tool specific logging
- `boo.peekaboo.app` - Mac app
- `boo.peekaboo.playground` - Playground test app
- `boo.peekaboo.inspector` - Inspector app
- `boo.peekaboo` - General Mac app components

### Solution 2: Code-Level Fix (Production Safe)

For production use, mark specific non-sensitive values as public in Swift:

```swift
// Before (will show as <private>):
logger.info("Connected to \(sessionId)")

// After (always visible):
logger.info("Connected to \(sessionId, privacy: .public)")
```

This is safer as it only exposes specific values you choose. **This is often the ONLY way to see dynamic string values in production logs.**

### Solution 3: Passwordless sudo for Convenience

While sudo doesn't reveal private data, setting up passwordless sudo is still useful for running log commands without password prompts.

#### Setup

1. **Edit sudoers file**:
   ```bash
   sudo visudo
   ```

2. **Add the NOPASSWD rule** (replace `yourusername` with your actual username):
   ```
   yourusername ALL=(ALL) NOPASSWD: /usr/bin/log
   ```

3. **Save and exit**:
   - Press `Esc` to enter command mode
   - Type `:wq` and press Enter to save and quit

4. **Test it**:
   ```bash
   # This should work without asking for password:
   sudo -n log show --last 1s
   
   # Now pblog.sh with private flag works without password:
   ./scripts/pblog.sh -p
   ```

#### Security Considerations

**What this allows:**
- ✅ Passwordless access to `log` command only
- ✅ Can view all system logs without password
- ✅ Can stream logs in real-time

**What this does NOT allow:**
- ❌ Cannot run other commands with sudo
- ❌ Cannot modify system files
- ❌ Cannot install software
- ❌ Cannot change system settings

## Using pblog.sh

pblog is Peekaboo's log viewer utility. With passwordless sudo configured, you can use:

```bash
# View all logs with private data visible (requires sudo)
./scripts/pblog.sh -p

# Filter by category with private data
./scripts/pblog.sh -p -c PrivacyTest

# Follow logs in real-time
./scripts/pblog.sh -f

# Search for errors
./scripts/pblog.sh -e -l 1h

# Combine filters
./scripts/pblog.sh -p -c ClickService -s "session" -f
```

## Testing Privacy Behavior

Peekaboo includes built-in privacy test logging:

1. **Run the CLI** (any command will trigger the test logs):
   ```bash
   ./peekaboo --version
   ```

2. **Check logs without the profile** (see what's redacted):
   ```bash
   ./scripts/pblog.sh -c PrivacyTest -l 1m
   ```
   
   You should see:
   - Some values like email/token are visible
   - Session IDs and paths show as `<private>`

3. **After installing the profile**, check again:
   ```bash
   ./scripts/pblog.sh -c PrivacyTest -l 1m
   ```
   
   Now all values should be visible, including previously redacted ones.

## Alternative Solutions

### Touch ID for sudo (if you have a Mac with Touch ID)

Edit `/etc/pam.d/sudo`:
```bash
sudo vi /etc/pam.d/sudo
```

Add this line at the top (after the comment):
```
auth       sufficient     pam_tid.so
```

Now you can use your fingerprint instead of typing password.

### Extend sudo timeout

Make sudo remember your password longer:
```bash
sudo visudo
```

Add:
```
Defaults timestamp_timeout=60
```

This keeps sudo active for 60 minutes after each use.

## Troubleshooting

### "sudo: a password is required"
- Make sure you saved the sudoers file (`:wq` in vi)
- Try in a new terminal window
- Run `sudo -k` to clear sudo cache, then try again
- Verify the line exists: `sudo grep NOPASSWD /etc/sudoers`

### "syntax error" when saving sudoers
- Never edit `/etc/sudoers` directly!
- Always use `sudo visudo` - it checks syntax before saving
- Make sure the line format is exactly:
  ```
  username ALL=(ALL) NOPASSWD: /usr/bin/log
  ```

### Still seeing `<private>` after installing profile
- Wait 1-2 minutes for the profile to take effect
- Generate fresh logs after installing the profile
- Verify the profile is installed in System Settings
- Try restarting Terminal app

### Profile not appearing in System Settings
- Make sure you're looking in the right place:
  - macOS 15+: General > Device Management
  - macOS 14 and earlier: Privacy & Security > Profiles
- Try downloading and opening the profile again

## Summary

**For debugging**: Use the configuration profile to temporarily enable private data logging. This is the most reliable way to see all log data.

**For production**: Mark specific non-sensitive values as `.public` in your Swift code.

**For convenience**: Set up passwordless sudo to avoid typing your password when viewing logs.

Remember: The configuration profile disables ALL privacy protection for Peekaboo logs. Always remove it after debugging!

## References

- [Removing privacy censorship from the log - The Eclectic Light Company](https://eclecticlight.co/2023/03/08/removing-privacy-censorship-from-the-log/)
- [Apple Developer - Logging](https://developer.apple.com/documentation/os/logging)
- [Apple Developer - OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy)