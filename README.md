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
- 🤖 **AI Vision Analysis**: Local Ollama integration with auto-model detection

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

# 🤖 AI analysis: Screenshot + question in one step
osascript peekaboo.scpt "Safari" --ask "What's on this page?"

# 🔍 Analyze existing image
osascript peekaboo.scpt analyze "/tmp/screenshot.png" "Any errors visible?"
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

## 🤖 **AI VISION ANALYSIS**

Peekaboo integrates with **Ollama** for local AI vision analysis - ask questions about your screenshots!

### 🚀 **One-Step: Screenshot + Analysis**
```bash
# Take screenshot and analyze it in one command
osascript peekaboo.scpt "Safari" --ask "What's the main content on this page?"
osascript peekaboo.scpt "Terminal" --ask "Any error messages visible?"
osascript peekaboo.scpt "Xcode" --ask "Is the build successful?"
osascript peekaboo.scpt "Chrome" --ask "What product is being shown?" --model llava:13b
```

### 🔍 **Two-Step: Analyze Existing Images**  
```bash
# Analyze screenshots you already have
osascript peekaboo.scpt analyze "/tmp/screenshot.png" "Describe what you see"
osascript peekaboo.scpt analyze "/path/error.png" "What error is shown?"
osascript peekaboo.scpt analyze "/Desktop/ui.png" "Any UI issues?" --model qwen2.5vl:7b
```

### 🧠 **Smart Model Selection**
Peekaboo automatically picks the best available vision model:

**Priority order:**
1. `qwen2.5vl:7b` (6GB) - Best doc/chart understanding  
2. `llava:7b` (4.7GB) - Solid all-rounder
3. `llava-phi3:3.8b` (2.9GB) - Tiny but chatty
4. `minicpm-v:8b` (5.5GB) - Killer OCR
5. `gemma3:4b` (3.3GB) - Multilingual support

### ⚡ **Quick Setup**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a vision model (pick one)
ollama pull qwen2.5vl:7b    # Recommended: best overall
ollama pull llava:7b        # Popular: good balance  
ollama pull llava-phi3:3.8b # Lightweight: low RAM

# Ready to analyze!
osascript peekaboo.scpt "Safari" --ask "What's on this page?"
```

**Perfect for:**
- 🧪 Automated UI testing  
- 📊 Dashboard monitoring
- 🐛 Error detection
- 📸 Content verification
- 🔍 Visual QA automation

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

# Automated visual testing with AI
osascript peekaboo.scpt "Your App" --ask "Any error messages or crashes visible?"
osascript peekaboo.scpt "Your App" --ask "Is the login screen displayed correctly?"

# Custom path with timestamp
osascript peekaboo.scpt "Your App" "/test-results/app-$(date +%s).png"
```

### 🎬 **Content Creation**
```bash
# Before/after shots with AI descriptions
osascript peekaboo.scpt "Photoshop" --ask "Describe the current design state"
# ... do your work ...
osascript peekaboo.scpt "Photoshop" --ask "What changes were made to the design?"

# Traditional before/after shots
osascript peekaboo.scpt "Photoshop" "/content/before.png"
# ... do your work ...
osascript peekaboo.scpt "Photoshop" "/content/after.png"
```

### 🧪 **Automated QA & Testing**
```bash
# Visual regression testing
osascript peekaboo.scpt "Your App" --ask "Does the UI look correct?"
osascript peekaboo.scpt "Safari" --ask "Are there any broken images or layout issues?"
osascript peekaboo.scpt "Terminal" --ask "Any red error text visible?"

# Dashboard monitoring
osascript peekaboo.scpt analyze "/tmp/dashboard.png" "Are all metrics green?"
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
| **AI Vision Analysis** | ✅ Local Ollama integration with auto-model detection |
| **Smart AI Models** | ✅ Auto-picks best: qwen2.5vl > llava > phi3 > minicpm |
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
- **Smart AI analysis**: Auto-detects best vision model
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

### 🤖 **AI-Powered Vision**
- **Local analysis**: Private Ollama integration, no cloud
- **Smart model selection**: Auto-picks best available model  
- **One or two-step**: Screenshot+analyze or analyze existing images
- **Perfect for automation**: Visual testing, error detection, QA

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