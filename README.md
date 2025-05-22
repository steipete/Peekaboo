# Peekaboo—screenshot got you! Now you see it, now it's saved.

![Peekaboo Banner](assets/banner.png)

👀 → 📸 → 💾 — **Unattended screenshot automation that actually works**

---

## 🚀 **THE MAGIC**

**Peekaboo** is your silent screenshot assassin. Point it at any app, and SNAP! — it's captured and saved before you can blink.

- 🎯 **Smart targeting**: App names or bundle IDs
- 🚀 **Auto-launch**: Sleeping apps? No problem!
- 👁 **Brings apps forward**: Always gets the shot
- 🏗 **Creates directories**: Paths don't exist? Fixed!
- 🎨 **Multi-format**: PNG, JPG, PDF — you name it
- 💥 **Zero interaction**: 100% unattended operation
- 🧠 **Smart filenames**: Model-friendly names with app info
- ⚡ **Optimized speed**: 70% faster capture delays

---

## 🎪 **HOW TO USE**

### 🎯 **Basic Usage**
*Simple screenshot capture*

```bash
# 👀 Quick shot with smart filename
osascript peekaboo.scpt "Safari"
# → /tmp/peekaboo_safari_20250522_143052.png

# 🎯 Custom output path
osascript peekaboo.scpt "Safari" "/Users/you/Desktop/safari.png"

# 🎯 Bundle ID targeting  
osascript peekaboo.scpt "com.apple.TextEdit" "/tmp/textedit.jpg"
```

### 🎪 **Advanced Features**
*All the power. All the windows. All the time.*

```bash
# 🔍 What's running right now?
osascript peekaboo.scpt list

# 👀 Quick shot to /tmp with timestamp
osascript peekaboo.scpt "Chrome"

# 🎭 Capture ALL windows with smart names
osascript peekaboo.scpt "Chrome" "/tmp/chrome.png" --multi

# 🪟 Just the front window  
osascript peekaboo.scpt "TextEdit" "/tmp/textedit.png" --window
```

---

## ⚡ **QUICK WINS**

### 🎯 **Basic Shot**
```bash
# Quick shot with auto-generated filename
osascript peekaboo.scpt "Finder"
```
**Result**: Full screen with Finder in focus → `/tmp/peekaboo_finder_20250522_143052.png`
*Notice the smart filename: app name + timestamp, all lowercase with underscores*

```bash
# Custom path
osascript peekaboo.scpt "Finder" "/Desktop/finder.png"
```
**Result**: Full screen with Finder in focus → `finder.png`

### 🎭 **Multi-Window Magic**  
```bash
osascript peekaboo.scpt "Safari" "/tmp/safari.png" --multi
```
**Result**: Multiple files with smart names:
- `safari_window_1_github.png`
- `safari_window_2_documentation.png`  
- `safari_window_3_google_search.png`

### 🔍 **App Discovery**
```bash
osascript peekaboo.scpt list
```
**Result**: Every running app + window titles. No guessing!

---

## 🛠 **SETUP** 

### 1️⃣ **Make Executable**
```bash
chmod +x peekaboo.scpt
```

### 2️⃣ **Grant Powers**
- System Preferences → Security & Privacy → **Screen Recording**
- Add your terminal app to the list
- ✨ You're golden!

---

## 🎨 **FORMAT PARTY**

Peekaboo speaks all the languages:

```bash
# PNG (default) - smart filename in /tmp
osascript peekaboo.scpt "Safari"
# → /tmp/peekaboo_safari_20250522_143052.png

# PNG with custom path
osascript peekaboo.scpt "Safari" "/tmp/shot.png"

# JPG - smaller files 
osascript peekaboo.scpt "Safari" "/tmp/shot.jpg"

# PDF - vector goodness
osascript peekaboo.scpt "Safari" "/tmp/shot.pdf"
```

---

## 🧠 **SMART FILENAMES**

Peekaboo automatically generates **model-friendly** filenames that are perfect for automation:

```bash
# App names become lowercase with underscores
osascript peekaboo.scpt "Safari"               → peekaboo_safari_TIMESTAMP.png
osascript peekaboo.scpt "Activity Monitor"     → peekaboo_activity_monitor_TIMESTAMP.png
osascript peekaboo.scpt "com.apple.TextEdit"   → peekaboo_com_apple_textedit_TIMESTAMP.png
osascript peekaboo.scpt "Final Cut Pro"        → peekaboo_final_cut_pro_TIMESTAMP.png

# Multi-window gets descriptive names
osascript peekaboo.scpt "Chrome" --multi       → chrome_window_1_github.png
                                                → chrome_window_2_documentation.png
```

**Perfect for:**
- 🤖 AI model file references  
- 📝 Scripting and automation
- 🔍 Easy file searching
- 📊 Batch processing

---

## 🏆 **POWER MOVES**

### 🎯 **Targeting Options**
```bash
# By name (easy) - smart filename
osascript peekaboo.scpt "Safari"
# → /tmp/peekaboo_safari_20250522_143052.png

# By name with custom path
osascript peekaboo.scpt "Safari" "/tmp/safari.png"

# By bundle ID (precise) - gets sanitized
osascript peekaboo.scpt "com.apple.Safari"
# → /tmp/peekaboo_com_apple_safari_20250522_143052.png

# By display name (works too!) - spaces become underscores
osascript peekaboo.scpt "Final Cut Pro"
# → /tmp/peekaboo_final_cut_pro_20250522_143052.png
```

### 🎪 **Pro Features**
```bash
# Multi-window capture
--multi         # All windows with descriptive names

# Window modes  
--window        # Front window only (unattended!)

# Debug mode
--verbose       # See what's happening under the hood
```

### 🔍 **Discovery Mode**
```bash
osascript peekaboo.scpt list
```
Shows you:
- 📱 All running apps
- 🆔 Bundle IDs  
- 🪟 Window counts
- 📝 Exact window titles

---

## 🎭 **REAL-WORLD SCENARIOS**

### 📊 **Documentation Screenshots**
```bash
# Quick capture to /tmp
osascript peekaboo.scpt "Xcode" --multi
osascript peekaboo.scpt "Terminal" --multi
osascript peekaboo.scpt "Safari" --multi

# Capture your entire workflow with custom paths
osascript peekaboo.scpt "Xcode" "/docs/xcode.png" --multi
osascript peekaboo.scpt "Terminal" "/docs/terminal.png" --multi
osascript peekaboo.scpt "Safari" "/docs/browser.png" --multi
```

### 🚀 **CI/CD Integration**
```bash
# Quick automated testing screenshots with smart names
osascript peekaboo.scpt "Your App"
# → /tmp/peekaboo_your_app_20250522_143052.png

# Custom path with timestamp
osascript peekaboo.scpt "Your App" "/test-results/app-$(date +%s).png"
```

### 🎬 **Content Creation**
```bash
# Before/after shots
osascript peekaboo.scpt "Photoshop" "/content/before.png"
# ... do your work ...
osascript peekaboo.scpt "Photoshop" "/content/after.png"
```

---

## 🚨 **TROUBLESHOOTING**

### 🔐 **Permission Denied?**
- Check Screen Recording permissions
- Restart your terminal after granting access

### 👻 **App Not Found?**
```bash
# See what's actually running
osascript peekaboo.scpt list

# Try the bundle ID instead
osascript peekaboo.scpt "com.company.AppName" "/tmp/shot.png"
```

### 📁 **File Not Created?**
- Check the output directory exists (Peekaboo creates it!)
- Verify disk space
- Try a simple `/tmp/test.png` first

### 🐛 **Debug Mode**
```bash
osascript peekaboo.scpt "Safari" "/tmp/debug.png" --verbose
```

---

## 🎪 **FEATURES**

| Feature | Description |
|---------|-------------|
| **Basic screenshots** | ✅ Full screen capture with app targeting |
| **App targeting** | ✅ By name or bundle ID |
| **Multi-format** | ✅ PNG, JPG, PDF support |
| **App discovery** | ✅ `list` command shows running apps |
| **Multi-window** | ✅ `--multi` captures all app windows |
| **Smart naming** | ✅ Descriptive filenames for windows |
| **Window modes** | ✅ `--window` for front window only |
| **Auto paths** | ✅ Optional output path with smart /tmp defaults |
| **Smart filenames** | ✅ Model-friendly: app_name_timestamp format |
| **Verbose logging** | ✅ `--verbose` for debugging |

---

## 🧪 **TESTING**

We've got you covered:

```bash
# Run the full test suite
./test_screenshotter.sh

# Test and cleanup
./test_screenshotter.sh --cleanup
```

Tests everything:
- ✅ App resolution (names + bundle IDs)
- ✅ Format support (PNG, JPG, PDF)  
- ✅ Error handling
- ✅ Directory creation
- ✅ File validation
- ✅ Multi-window scenarios

---

## ⚙️ **CUSTOMIZATION**

Tweak the magic in the script headers:

```applescript
property captureDelay : 1.0              -- Wait before snap
property windowActivationDelay : 0.5     -- Window focus time
property enhancedErrorReporting : true   -- Detailed errors
property verboseLogging : false          -- Debug output
```

---

## 🎉 **WHY PEEKABOO ROCKS**

### 🚀 **Unattended = Unstoppable**
- No clicking, no selecting, no babysitting
- Perfect for automation and CI/CD
- Set it and forget it

### 🧠 **Smart Everything**
- **Smart filenames**: Model-friendly with app names
- **Smart targeting**: Works with app names OR bundle IDs
- **Smart delays**: Optimized for speed (70% faster)
- Auto-launches sleeping apps and brings them forward

### 🎭 **Multi-Window Mastery**
- Captures ALL windows with descriptive names
- Safe filename generation with sanitization
- Never overwrites accidentally

### ⚡ **Blazing Fast**
- **0.3s capture delay** (down from 1.0s)
- **0.2s window activation** (down from 0.5s) 
- **0.1s multi-window focus** (down from 0.3s)
- Responsive and practical for daily use

### 🔍 **Discovery Built-In**
- See exactly what's running
- Get precise window titles
- No more guessing games

---

## 📚 **INSPIRED BY**

Built in the style of the legendary **terminator.scpt** — because good patterns should be celebrated and extended.

---

## 🎪 **PROJECT FILES**

```
📁 Peekaboo/
├── 🎯 peekaboo.scpt              # Main screenshot tool
├── 🧪 test_screenshotter.sh      # Test suite
└── 📖 README.md                  # This awesomeness
```

---

## 🏆 **THE BOTTOM LINE**

**Peekaboo** doesn't just take screenshots. It **conquers** them.

👀 Point → 📸 Shoot → 💾 Save → 🎉 Done!

*Now you see it, now it's saved. Peekaboo!*

---

*Built with ❤️ and lots of ☕ for the macOS automation community.*