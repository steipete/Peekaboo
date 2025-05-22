# Peekaboo — The screenshot tool that just works™

![Peekaboo Banner](assets/banner.png)

👀 → 📸 → 💾 — **Zero-click screenshots with AI superpowers**

---

## ✨ **FEATURES**

🎯 **Clean CLI** • 🤫 **Quiet Mode** • 🤖 **AI Support** • ⚡ **Non-Interactive** • 🪟 **Multi-Window**

---

## 🚀 **THE MAGIC**

**Peekaboo** captures any app, any window, any time — no clicking required. Now with a beautiful command-line interface and AI vision analysis.

### 🎯 **Core Features**
- **Smart capture**: App window by default, fullscreen when no app specified
- **Zero interaction**: Uses window IDs, not mouse clicks
- **AI vision**: Ask questions about your screenshots (Ollama + Claude CLI)
- **Quiet mode**: Perfect for scripts and automation (`-q`)
- **Multi-window**: Capture all app windows separately (`-m`)
- **Format control**: PNG, JPG, PDF with auto-detection
- **Smart paths**: Auto-generated filenames or custom paths
- **Fast & reliable**: Optimized delays, robust error handling

### 🌟 **Key Highlights**
- **Smart Multi-Window AI**: Automatically analyzes ALL windows for multi-window apps
- **Timeout Protection**: 90-second timeout prevents hanging on slow models  
- **Clean CLI Design**: Consistent flags, short aliases, logical defaults
- **Claude CLI support**: Smart provider selection (Ollama preferred)
- **Performance tracking**: See how long AI analysis takes
- **Comprehensive help**: Clear sections, real examples

---

## 🎯 **QUICK START**

```bash
# Install (one-time)
chmod +x peekaboo.scpt

# Basic usage
osascript peekaboo.scpt              # Capture fullscreen
osascript peekaboo.scpt Safari       # Capture Safari window
osascript peekaboo.scpt help         # Show all options
```

---

## 📖 **COMMAND REFERENCE**

### 🎨 **Command Structure**
```
peekaboo [app] [options]                    # Capture app or fullscreen
peekaboo analyze <image> "question" [opts]  # Analyze existing image
peekaboo list|ls                            # List running apps
peekaboo help|-h                            # Show help
```

### 🏷️ **Options**
| Option | Short | Description |
|--------|-------|-------------|
| `--output <path>` | `-o` | Output file or directory path |
| `--fullscreen` | `-f` | Force fullscreen capture |
| `--window` | `-w` | Single window (default with app) |
| `--multi` | `-m` | Capture all app windows |
| `--ask "question"` | `-a` | AI analysis of screenshot |
| `--quiet` | `-q` | Minimal output (just path) |
| `--verbose` | `-v` | Debug output |
| `--format <fmt>` | | Output format: png\|jpg\|pdf |
| `--model <model>` | | AI model (e.g., llava:7b) |
| `--provider <p>` | | AI provider: auto\|ollama\|claude |

---

## 🎪 **USAGE EXAMPLES**

### 📸 **Basic Screenshots**
```bash
# Simplest captures
osascript peekaboo.scpt                    # Fullscreen → /tmp/peekaboo_fullscreen_[timestamp].png
osascript peekaboo.scpt Safari             # Safari window → /tmp/peekaboo_safari_[timestamp].png
osascript peekaboo.scpt com.apple.Terminal # Using bundle ID → /tmp/peekaboo_com_apple_terminal_[timestamp].png

# Custom output paths
osascript peekaboo.scpt Safari -o ~/Desktop/safari.png
osascript peekaboo.scpt Finder -o ~/screenshots/finder.jpg --format jpg
osascript peekaboo.scpt -f -o ~/fullscreen.pdf  # Fullscreen as PDF
```

### 🤫 **Quiet Mode** (Perfect for Scripts)
```bash
# Just get the file path - no extra output
FILE=$(osascript peekaboo.scpt Safari -q)
echo "Screenshot saved to: $FILE"

# Use in scripts
SCREENSHOT=$(osascript peekaboo.scpt Terminal -q)
scp "$SCREENSHOT" user@server:/uploads/

# Chain commands
osascript peekaboo.scpt Finder -q | pbcopy  # Copy path to clipboard
```

### 🎭 **Multi-Window Capture**
```bash
# Capture all windows of an app
osascript peekaboo.scpt Chrome -m
# Creates: /tmp/peekaboo_chrome_[timestamp]_window_1_[title].png
#          /tmp/peekaboo_chrome_[timestamp]_window_2_[title].png
#          etc.

# Save to specific directory
osascript peekaboo.scpt Safari -m -o ~/safari-windows/
# Creates: ~/safari-windows/peekaboo_safari_[timestamp]_window_1_[title].png
#          ~/safari-windows/peekaboo_safari_[timestamp]_window_2_[title].png
```

### 🤖 **AI Vision Analysis**
```bash
# One-step: Screenshot + Analysis
osascript peekaboo.scpt Safari -a "What website is this?"
osascript peekaboo.scpt Terminal -a "Are there any error messages?"
osascript peekaboo.scpt -f -a "Describe what's on my screen"

# Specify AI model
osascript peekaboo.scpt Xcode -a "Is the build successful?" --model llava:13b

# Two-step: Analyze existing image
osascript peekaboo.scpt analyze screenshot.png "What do you see?"
osascript peekaboo.scpt analyze error.png "Explain this error" --provider ollama
```

### 🔍 **App Discovery**
```bash
# List all running apps with window info
osascript peekaboo.scpt list
osascript peekaboo.scpt ls    # Short alias

# Output:
# • Google Chrome (com.google.Chrome)
#   Windows: 3
#     - "GitHub - Project"
#     - "Documentation"
#     - "Stack Overflow"
# • Safari (com.apple.Safari)
#   Windows: 2
#     - "Apple.com"
#     - "News"
```

### 🎯 **Advanced Combinations**
```bash
# Quiet fullscreen with custom path and format
osascript peekaboo.scpt -f -o ~/desktop-capture --format jpg -q

# Multi-window with AI analysis (analyzes first window)
osascript peekaboo.scpt Chrome -m -a "What tabs are open?"

# Verbose mode for debugging
osascript peekaboo.scpt Safari -v -o ~/debug.png

# Force window mode on fullscreen request
osascript peekaboo.scpt Safari -f -w  # -w overrides -f
```

---

## ⚡ **QUICK WINS**

### 🎯 **Basic Captures**
```bash
# Fullscreen (no app specified)
osascript peekaboo.scpt
```
**Result**: Full screen → `/tmp/peekaboo_fullscreen_20250522_143052.png`

```bash
# App window with smart filename
osascript peekaboo.scpt Finder
```
**Result**: Finder window → `/tmp/peekaboo_finder_20250522_143052.png`

```bash
# Custom output path
osascript peekaboo.scpt Finder -o ~/Desktop/finder.png
```
**Result**: Finder window → `~/Desktop/finder.png`

### 🎭 **Multi-Window Magic**  
```bash
osascript peekaboo.scpt Safari -m
```
**Result**: Multiple files with smart names:
- `/tmp/peekaboo_safari_20250522_143052_window_1_github.png`
- `/tmp/peekaboo_safari_20250522_143052_window_2_docs.png`  
- `/tmp/peekaboo_safari_20250522_143052_window_3_search.png`

```bash
# Save to specific directory
osascript peekaboo.scpt Chrome -m -o ~/screenshots/
```
**Result**: All Chrome windows saved to `~/screenshots/` directory

### 🔍 **App Discovery**
```bash
osascript peekaboo.scpt list   # or use 'ls'
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
osascript peekaboo.scpt Safari
# → /tmp/peekaboo_safari_20250522_143052.png

# JPG with format flag
osascript peekaboo.scpt Safari -o ~/shot --format jpg
# → ~/shot.jpg

# PDF - vector goodness
osascript peekaboo.scpt Safari -o ~/doc.pdf
# → ~/doc.pdf (format auto-detected from extension)

# Mix and match options
osascript peekaboo.scpt -f --format jpg -o ~/fullscreen -q
# → ~/fullscreen.jpg (quiet mode just prints path)
```

---

## 🤖 **AI VISION ANALYSIS** ⭐

Peekaboo integrates with AI providers for powerful vision analysis - ask questions about your screenshots! Supports both **Ollama** (local, privacy-focused) and **Claude CLI** (cloud-based).

**🪟 Smart Multi-Window AI** - When analyzing apps with multiple windows, Peekaboo automatically captures and analyzes ALL windows, giving you comprehensive insights about each one!

### 🎯 **Key Features**
- **🤖 Smart Provider Selection** - Auto-detects Ollama or Claude CLI
- **🧠 Smart Model Auto-Detection** - Automatically picks the best available vision model (Ollama)
- **📏 Intelligent Image Resizing** - Auto-compresses large screenshots (>5MB → 2048px) for optimal AI processing
- **🪟 Smart Multi-Window Analysis** - Automatically analyzes ALL windows when app has multiple windows
- **⚡ One or Two-Step Workflows** - Screenshot+analyze or analyze existing images
- **🔒 Privacy Options** - Choose between local (Ollama) or cloud (Claude) analysis
- **⏱️ Performance Tracking** - Shows analysis time for each request
- **⛰️ Timeout Protection** - 90-second timeout prevents hanging on slow models
- **🎯 Zero Configuration** - Just install your preferred AI provider, Peekaboo handles the rest

### 🚀 **One-Step: Screenshot + Analysis**
```bash
# Take screenshot and analyze it in one command (auto-selects provider)
osascript peekaboo.scpt Safari -a "What's the main content on this page?"
osascript peekaboo.scpt Terminal -a "Any error messages visible?"
osascript peekaboo.scpt Xcode -a "Is the build successful?"

# Multi-window apps: Automatically analyzes ALL windows!
osascript peekaboo.scpt Chrome -a "What tabs are open?"
# 🤖 Result: Window 1 "GitHub": Shows a pull request page...
#           Window 2 "Docs": Shows API documentation...
#           Window 3 "Gmail": Shows email inbox...

# Force single window with -w flag
osascript peekaboo.scpt Chrome -w -a "What's on this tab?"

# Specify AI provider explicitly
osascript peekaboo.scpt Chrome -a "What product is shown?" --provider ollama
osascript peekaboo.scpt Safari -a "Describe the page" --provider claude

# Specify custom model (Ollama)
osascript peekaboo.scpt Chrome -a "What product is being shown?" --model llava:13b

# Fullscreen analysis (no app specified)
osascript peekaboo.scpt -f -a "Describe what's on my screen"
osascript peekaboo.scpt -a "Any UI errors or warnings visible?" -v

# Quiet mode for scripting (just outputs path after analysis)
osascript peekaboo.scpt Terminal -a "Find errors" -q
```

### 🔍 **Two-Step: Analyze Existing Images**  
```bash
# Analyze screenshots you already have
osascript peekaboo.scpt analyze /tmp/screenshot.png "Describe what you see"
osascript peekaboo.scpt analyze error.png "What error is shown?"
osascript peekaboo.scpt analyze ui.png "Any UI issues?" --model qwen2.5vl:7b
```

### 🤖 **AI Provider Comparison**

| Provider | Type | Image Analysis | Setup | Best For |
|----------|------|---------------|-------|----------|
| **Ollama** | Local | ✅ Direct file analysis | Install + pull models | Privacy, automation |
| **Claude CLI** | Cloud | ❌ Limited support* | Install CLI | Text prompts |

*Claude CLI currently doesn't support direct image file analysis but can work with images through interactive mode or MCP integrations.

### 🛠️ **Complete Ollama Setup Guide** (Recommended for Image Analysis)

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

### 🪟 **Smart Multi-Window Analysis**
When an app has multiple windows, Peekaboo automatically analyzes ALL of them:

```bash
# Chrome with 3 tabs open? Peekaboo analyzes them all!
osascript peekaboo.scpt Chrome -a "What's on each tab?"

# Result format:
# Peekaboo 👀: Multi-window AI Analysis Complete! 🤖
# 
# 📸 App: Chrome (3 windows)
# ❓ Question: What's on each tab?
# 🤖 Model: qwen2.5vl:7b
#
# 💬 Results for each window:
#
# 🪟 Window 1: "GitHub - Pull Request #42"
# This shows a pull request for adding authentication...
#
# 🪟 Window 2: "Stack Overflow - Python threading"
# A Stack Overflow page discussing Python threading concepts...
#
# 🪟 Window 3: "Gmail - Inbox (42)"
# Gmail inbox showing 42 unread emails...
```

**Smart Defaults:**
- ✅ Multi-window apps → Analyzes ALL windows automatically
- ✅ Single window apps → Analyzes the one window
- ✅ Want just one window? → Use `-w` flag to force single window mode
- ✅ Quiet mode → Returns condensed results for each window

### ⏱️ **Performance Tracking & Timeouts**
Every AI analysis shows execution time and has built-in protection:
```
Peekaboo 👀: Analysis via qwen2.5vl:7b took 7 sec.
Peekaboo 👀: Analysis timed out after 90 seconds.
```

**Timeout Protection:**
- ⏰ 90-second timeout prevents hanging on large models
- 🛡️ Clear error messages if model is too slow
- 💡 Suggests using smaller models on timeout

**Perfect for:**
- 🧪 **Automated UI Testing** - "Any error messages visible?"
- 📊 **Dashboard Monitoring** - "Are all systems green?"  
- 🐛 **Error Detection** - "What errors are shown in this log?"
- 📸 **Content Verification** - "Does this page look correct?"
- 🔍 **Visual QA Automation** - "Any broken UI elements?"
- 📱 **App State Verification** - "Is the login successful?"
- ⏱️ **Performance Benchmarking** - Compare model speeds

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
osascript peekaboo.scpt Safari
# → /tmp/peekaboo_safari_20250522_143052.png

# By name with custom path
osascript peekaboo.scpt Safari -o /tmp/safari.png

# By bundle ID (precise) - gets sanitized
osascript peekaboo.scpt com.apple.Safari
# → /tmp/peekaboo_com_apple_safari_20250522_143052.png

# By display name (works too!) - spaces become underscores
osascript peekaboo.scpt "Final Cut Pro"
# → /tmp/peekaboo_final_cut_pro_20250522_143052.png
```

### 🎪 **Pro Features**
```bash
# Multi-window capture
-m, --multi     # All windows with descriptive names

# Window modes  
-w, --window    # Front window only (unattended!)
-f, --fullscreen # Force fullscreen capture

# Output control
-q, --quiet     # Minimal output (just path)
-v, --verbose   # See what's happening under the hood
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
# Quick capture to /tmp with descriptive names
osascript peekaboo.scpt Xcode -m
osascript peekaboo.scpt Terminal -m
osascript peekaboo.scpt Safari -m

# Capture your entire workflow to specific directory
osascript peekaboo.scpt Xcode -m -o /docs/
osascript peekaboo.scpt Terminal -m -o /docs/
osascript peekaboo.scpt Safari -m -o /docs/

# Or specific files
osascript peekaboo.scpt Xcode -o /docs/xcode.png
osascript peekaboo.scpt Terminal -o /docs/terminal.png
osascript peekaboo.scpt Safari -o /docs/browser.png
```

### 🚀 **CI/CD Integration**
```bash
# Quick automated testing screenshots with smart names
osascript peekaboo.scpt "Your App"
# → /tmp/peekaboo_your_app_20250522_143052.png

# Automated visual testing with AI
osascript peekaboo.scpt "Your App" -a "Any error messages or crashes visible?"
osascript peekaboo.scpt "Your App" -a "Is the login screen displayed correctly?"

# Custom path with timestamp
osascript peekaboo.scpt "Your App" -o "/test-results/app-$(date +%s).png"

# Quiet mode for scripts (just outputs path)
SCREENSHOT=$(osascript peekaboo.scpt "Your App" -q)
echo "Screenshot saved: $SCREENSHOT"
```

### 🎬 **Content Creation**
```bash
# Before/after shots with AI descriptions
osascript peekaboo.scpt Photoshop -a "Describe the current design state"
# ... do your work ...
osascript peekaboo.scpt Photoshop -a "What changes were made to the design?"

# Traditional before/after shots
osascript peekaboo.scpt Photoshop -o /content/before.png
# ... do your work ...
osascript peekaboo.scpt Photoshop -o /content/after.png

# Capture all design windows
osascript peekaboo.scpt Photoshop -m -o /content/designs/
```

### 🧪 **Automated QA & Testing**
```bash
# Visual regression testing
osascript peekaboo.scpt "Your App" -a "Does the UI look correct?"
osascript peekaboo.scpt Safari -a "Are there any broken images or layout issues?"
osascript peekaboo.scpt Terminal -a "Any red error text visible?"

# Dashboard monitoring
osascript peekaboo.scpt analyze /tmp/dashboard.png "Are all metrics green?"

# Quiet mode for test scripts
if osascript peekaboo.scpt "Your App" -a "Any errors?" -q | grep -q "No errors"; then
    echo "✅ Test passed"
else
    echo "❌ Test failed"
fi
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
# or
osascript peekaboo.scpt ls

# Try the bundle ID instead
osascript peekaboo.scpt com.company.AppName -o /tmp/shot.png
```

### 📁 **File Not Created?**
- Check the output directory exists (Peekaboo creates it!)
- Verify disk space
- Try a simple `/tmp/test.png` first

### 🐛 **Debug Mode**
```bash
osascript peekaboo.scpt Safari -o /tmp/debug.png -v
# or
osascript peekaboo.scpt Safari --output /tmp/debug.png --verbose
```

---

## 🎪 **FEATURES**

| Feature | Description |
|---------|-------------|
| **Basic screenshots** | ✅ Full screen capture with app targeting |
| **App targeting** | ✅ By name or bundle ID |
| **Multi-format** | ✅ PNG, JPG, PDF support |
| **App discovery** | ✅ `list`/`ls` command shows running apps |
| **Multi-window** | ✅ `-m`/`--multi` captures all app windows |
| **Smart naming** | ✅ Descriptive filenames for windows |
| **Window modes** | ✅ `-w`/`--window` for front window only |
| **Auto paths** | ✅ Optional output path with smart /tmp defaults |
| **Smart filenames** | ✅ Model-friendly: app_name_timestamp format |
| **AI Vision Analysis** | ✅ Ollama + Claude CLI support with smart fallback |
| **Smart AI Models** | ✅ Auto-picks best: qwen2.5vl > llava > phi3 > minicpm |
| **Smart Image Compression** | ✅ Auto-resizes large images (>5MB → 2048px) for AI |
| **AI Provider Selection** | ✅ Auto-detect or specify with `--provider` flag |
| **Performance Tracking** | ✅ Shows analysis time for benchmarking |
| **Cloud AI Integration** | ✅ Self-documenting for Claude, Windsurf, ChatGPT, etc. |
| **Quiet mode** | ✅ `-q`/`--quiet` for minimal output |
| **Verbose logging** | ✅ `-v`/`--verbose` for debugging |

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
- **Multi-window intelligence**: Analyzes ALL windows automatically
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
├── 🧪 test_peekaboo.sh          # Comprehensive test suite
├── 📖 README.md                  # This awesomeness
└── 🎨 assets/
    └── banner.png               # Project banner
```

---

## 🏆 **THE BOTTOM LINE**

**Peekaboo** doesn't just take screenshots. It **conquers** them.

👀 Point → 📸 Shoot → 💾 Save → 🎉 Done!

*Now you see it, now it's saved. Peekaboo!*

---

*Built with ❤️ and lots of ☕ for the macOS automation community.*