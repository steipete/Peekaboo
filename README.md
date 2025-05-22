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
- ☁️ **Cloud AI Ready**: Self-documenting for Claude, Windsurf, ChatGPT integration

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

## 🤖 **AI VISION ANALYSIS** ⭐

Peekaboo integrates with **Ollama** for powerful local AI vision analysis - ask questions about your screenshots! No cloud, no API keys, just pure local magic.

### 🎯 **Key Features**
- **🧠 Smart Model Auto-Detection** - Automatically picks the best available vision model
- **📏 Intelligent Image Resizing** - Auto-compresses large screenshots (>5MB → 2048px) for optimal AI processing
- **⚡ One or Two-Step Workflows** - Screenshot+analyze or analyze existing images
- **🔒 100% Local & Private** - Everything runs on your machine via Ollama
- **🎯 Zero Configuration** - Just install Ollama + model, Peekaboo handles the rest

### 🚀 **One-Step: Screenshot + Analysis**
```bash
# Take screenshot and analyze it in one command
osascript peekaboo.scpt "Safari" --ask "What's the main content on this page?"
osascript peekaboo.scpt "Terminal" --ask "Any error messages visible?"
osascript peekaboo.scpt "Xcode" --ask "Is the build successful?"
osascript peekaboo.scpt "Chrome" --ask "What product is being shown?" --model llava:13b

# Fullscreen analysis (no app targeting needed)
osascript peekaboo.scpt --ask "Describe what's on my screen"
osascript peekaboo.scpt --verbose --ask "Any UI errors or warnings visible?"
```

### 🔍 **Two-Step: Analyze Existing Images**  
```bash
# Analyze screenshots you already have
osascript peekaboo.scpt analyze "/tmp/screenshot.png" "Describe what you see"
osascript peekaboo.scpt analyze "/path/error.png" "What error is shown?"
osascript peekaboo.scpt analyze "/Desktop/ui.png" "Any UI issues?" --model qwen2.5vl:7b
```

### 🛠️ **Complete Ollama Setup Guide**

#### 1️⃣ **Install Ollama**
```bash
# macOS (Homebrew)
brew install ollama

# Or direct install
curl -fsSL https://ollama.ai/install.sh | sh

# Or download from https://ollama.ai
```

#### 2️⃣ **Start Ollama Service**
```bash
# Start the service (runs in background)
ollama serve

# Or use the Ollama.app (GUI version)
# Download from https://ollama.ai → Double-click to install
```

#### 3️⃣ **Pull Vision Models**
```bash
# 🏆 Recommended: Best overall (6GB)
ollama pull qwen2.5vl:7b

# 🚀 Popular choice: Good balance (4.7GB)  
ollama pull llava:7b

# ⚡ Lightweight: Low RAM usage (2.9GB)
ollama pull llava-phi3:3.8b

# 🔍 OCR specialist: Great for text (5.5GB)
ollama pull minicpm-v:8b

# 🌍 Latest and greatest: Cutting edge (11GB)
ollama pull llama3.2-vision:11b
```

#### 4️⃣ **Verify Setup**
```bash
# Check running models
ollama list

# Test vision analysis
osascript peekaboo.scpt --ask "What do you see on my screen?"
```

### 🧠 **Smart Model Selection**
Peekaboo automatically picks the best available vision model in priority order:

| Model | Size | Strengths | Best For |
|-------|------|-----------|----------|
| **qwen2.5vl:7b** | 6GB | 🏆 Document/chart analysis | Technical screenshots, code, UI |
| **llava:7b** | 4.7GB | 🚀 Well-rounded performance | General purpose, balanced usage |
| **llava-phi3:3.8b** | 2.9GB | ⚡ Fast & lightweight | Low-resource systems, quick analysis |
| **minicpm-v:8b** | 5.5GB | 🔍 Superior OCR accuracy | Text-heavy images, error messages |
| **llama3.2-vision:11b** | 11GB | 🌟 Latest technology | Best quality, high-end systems |

### 📏 **Smart Image Processing**
Peekaboo automatically optimizes images for AI analysis:

```bash
# Large screenshots (>5MB) are automatically compressed
🔍 Image size: 7126888 bytes
🔍 Image is large (7126888 bytes), creating compressed version for AI
# → Resized to 2048px max dimension while preserving aspect ratio
# → Maintains quality while ensuring fast AI processing
```

**Benefits:**
- ✅ **Faster Analysis** - Smaller images = quicker AI responses
- ✅ **Reliable Processing** - Avoids API timeouts with huge images  
- ✅ **Preserves Originals** - Full-resolution screenshots remain untouched
- ✅ **Smart Compression** - Uses macOS native `sips` tool for quality resizing

### 💡 **Pro Usage Examples**

```bash
# Automated UI testing with smart resizing
osascript peekaboo.scpt "Your App" --ask "Any error dialogs or crashes visible?"

# High-resolution dashboard analysis (auto-compressed for AI)
osascript peekaboo.scpt "Grafana" --ask "Are all metrics healthy and green?"

# Detailed code review screenshots
osascript peekaboo.scpt "VS Code" --ask "Any syntax errors or warnings in the code?"

# Large-screen analysis (automatically handles 4K+ displays)
osascript peekaboo.scpt --ask "Describe the overall layout and any issues"
```

**Perfect for:**
- 🧪 **Automated UI Testing** - "Any error messages visible?"
- 📊 **Dashboard Monitoring** - "Are all systems green?"  
- 🐛 **Error Detection** - "What errors are shown in this log?"
- 📸 **Content Verification** - "Does this page look correct?"
- 🔍 **Visual QA Automation** - "Any broken UI elements?"
- 📱 **App State Verification** - "Is the login successful?"

---

## ☁️ **CLOUD AI INTEGRATION** 

Peekaboo works seamlessly with **any AI service** that can read files! Perfect for Claude Code, Windsurf, ChatGPT, or any other AI tool.

### 🚀 **Quick Cloud AI Setup**

**For AI tools like Claude Code, Windsurf, etc.:**

1. **Copy the script file** to your project directory:
   ```bash
   cp peekaboo.scpt /path/to/your/project/
   ```

2. **Tell your AI tool about it**:
   ```
   I have a screenshot automation tool called peekaboo.scpt in this directory. 
   It can capture screenshots of any app and save them automatically. 
   Please read the file to understand how to use it.
   ```

3. **Your AI will automatically understand** how to:
   - Take screenshots of specific apps
   - Use smart filenames with timestamps  
   - Capture multiple windows
   - Handle different output formats
   - Integrate with your workflow

### 💡 **Example AI Prompts**

```bash
# Ask your AI assistant:
"Use peekaboo.scpt to take a screenshot of Safari and save it to /tmp/webpage.png"

"Capture all Chrome windows with the multi-window feature"

"Take a screenshot of Xcode and then analyze if there are any build errors visible"

"Set up an automated screenshot workflow for testing my app"
```

### 🎯 **AI Tool Integration Examples**

**Claude Code / Windsurf:**
```
Use the peekaboo.scpt tool to capture screenshots during our development session. 
The script automatically handles app targeting, file paths, and smart naming.
```

**ChatGPT / GitHub Copilot:**
```
I have a screenshot automation script. Please read peekaboo.scpt and help me 
integrate it into my testing workflow.
```

**Custom AI Scripts:**
```python
import subprocess

def take_screenshot(app_name, output_path):
    """Use Peekaboo to capture app screenshots"""
    cmd = ["osascript", "peekaboo.scpt", app_name, output_path]
    return subprocess.run(cmd, capture_output=True, text=True)

# Your AI can now use this function automatically!
```

### 🧠 **Why AI Tools Love Peekaboo**

- **📖 Self-Documenting**: AI reads the script and understands all features instantly
- **🎯 Zero Config**: No API keys, no setup - just works  
- **🧠 Smart Outputs**: Model-friendly filenames make AI integration seamless
- **⚡ Reliable**: Unattended operation perfect for AI-driven workflows
- **🔍 Comprehensive**: From basic screenshots to multi-window analysis

**The AI tool will automatically discover:**
- All available command-line options (`--multi`, `--window`, `--verbose`)
- Smart filename generation patterns
- Error handling and troubleshooting
- Integration with local Ollama for AI analysis
- Testing capabilities and examples

### 🎪 **Cloud AI + Local AI Combo**

**Powerful workflow example:**
```bash
# 1. Use Peekaboo to capture and analyze locally
osascript peekaboo.scpt "Your App" --ask "Any errors visible?"

# 2. Your cloud AI assistant can read the results and provide guidance
# 3. Iterate and improve based on AI recommendations
# 4. Automate the entire process with AI-generated scripts
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
| **Smart Image Compression** | ✅ Auto-resizes large images (>5MB → 2048px) for AI |
| **Cloud AI Integration** | ✅ Self-documenting for Claude, Windsurf, ChatGPT, etc. |
| **Verbose logging** | ✅ `--verbose` for debugging |

---

## 🧪 **TESTING**

We've got you covered with comprehensive testing:

```bash
# Run the full test suite
./test_peekaboo.sh

# Test specific features
./test_peekaboo.sh ai           # AI vision analysis only
./test_peekaboo.sh advanced     # Multi-window, discovery, AI
./test_peekaboo.sh basic        # Core screenshot functionality
./test_peekaboo.sh quick        # Essential tests only

# Test and cleanup
./test_peekaboo.sh all --cleanup
```

**Complete Test Coverage:**
- ✅ Basic screenshots with smart filenames
- ✅ App resolution (names + bundle IDs)
- ✅ Format support (PNG, JPG, PDF)  
- ✅ Multi-window scenarios with descriptive names
- ✅ App discovery and window enumeration
- ✅ **AI vision analysis (8 comprehensive tests)**
  - One-step: Screenshot + AI analysis
  - Two-step: Analyze existing images
  - Model auto-detection and custom models
  - Error handling and edge cases
- ✅ Enhanced error messaging
- ✅ Performance and stress testing
- ✅ Integration workflows
- ✅ Compatibility with system apps

**AI Test Details:**
```bash
# Specific AI testing scenarios
./test_peekaboo.sh ai
```
- ✅ One-step screenshot + analysis workflow
- ✅ Custom model specification testing
- ✅ Two-step analysis of existing images  
- ✅ Complex questions with special characters
- ✅ Invalid model error handling
- ✅ Missing file error handling
- ✅ Malformed command validation
- ✅ Graceful Ollama/model availability checks

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