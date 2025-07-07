# AXorcist: The power of Swift compels your UI to obey!

<p align="center">
  <img src="assets/logo.png" alt="AXorcist Logo">
</p>

<p align="center">
  <strong>Swift wrapper for macOS Accessibility—chainable, fuzzy-matched queries<br>that read, click, and inspect any UI.</strong>
</p>

---

**AXorcist** harnesses the dark arts of macOS Accessibility APIs to give you supernatural control over any application's interface. Whether you're automating workflows, testing applications, or building assistive technologies, AXorcist provides the incantations you need to make UI elements bend to your will.

## ✨ Supernatural Powers

- **🔍 Element Summoning**: Conjure UI elements using flexible locator spells
- **📋 Attribute Divination**: Extract mystical properties from accessibility elements
- **⚡ Action Invocation**: Cast clicks, text input, and menu manipulation spells
- **🔄 Batch Sorcery**: Execute multiple enchantments efficiently in a single ritual
- **📜 Text Extraction**: Harvest textual essence from any UI element
- **🗺️ Path Navigation**: Navigate the ethereal element hierarchies with precision
- **🐛 Debug Scrying**: Comprehensive logging to troubleshoot your incantations
- **📊 JSON Grimoire**: Clean JSON input/output for seamless spell integration

## 📦 Summoning AXorcist

### Swift Package Manager

Invoke AXorcist into your project by adding it to your `Package.swift` grimoire:

```swift
dependencies: [
    .package(url: "https://github.com/steipete/AXorcist.git", from: "0.1.0")
]
```

### Command Line Familiar

Conjure the `axorc` command-line familiar:

```bash
git clone https://github.com/steipete/AXorcist.git
cd AXorcist
make build
make install
```

## 🚀 First Incantations

### Casting Swift Spells

```swift
import AXorcist

@MainActor
func example() async {
    let axorcist = AXorcist()
    var logs: [String] = []
    
    // Summon the focused element
    let result = axorcist.handleGetFocusedElement(
        for: "Safari", 
        requestedAttributes: ["AXRole", "AXTitle"],
        isDebugLoggingEnabled: true,
        currentDebugLogs: &logs
    )
    
    if let element = result.data {
        print("Behold! Element with attributes:", element.attributes)
    }
}
```

### Command Line Rituals

```bash
# Divine the focused element in any application
echo '{"command_id": "1", "command": "getFocusedElement"}' | axorc --stdin

# Summon a specific button with precise locator magic
echo '{
  "command_id": "2", 
  "command": "query",
  "locator": {
    "criteria": {
      "AXRole": "AXButton",
      "AXTitle": "Submit"
    }
  }
}' | axorc --stdin
```

## 📖 The Spell Book

### The AXorcist Entity

Your primary conduit to the accessibility realm, wielding eight powerful enchantments:

#### ⚡ Core Enchantments

- **`handleGetFocusedElement`**: Divine the currently focused UI element
- **`handleGetAttributes`**: Extract mystical properties using locator spells
- **`handleQuery`**: Summon elements matching your criteria
- **`handleDescribeElement`**: Reveal comprehensive element secrets
- **`handlePerformAction`**: Command UI elements to perform your bidding
- **`handleExtractText`**: Harvest textual essence from any element
- **`handleBatchCommands`**: Execute multiple spells in a single ritual
- **`handleCollectAll`**: Recursively gather all matching elements from the UI realm

#### 🧙‍♂️ Spell Components

All enchantments accept these mystical parameters:

- `appIdentifierOrNil`: Target application realm (bundle ID, name, or "focused")
- `locator`: Magical search criteria for element summoning
- `pathHint`: Array of breadcrumbs for UI navigation
- `maxDepth`: Maximum depth to traverse the element abyss
- `requestedAttributes`: Specific mystical properties to harvest
- `outputFormat`: Revelation format (`.smart`, `.verbose`, `.json_string`)
- `isDebugLoggingEnabled`: Enable arcane debug visions
- `currentDebugLogs`: Mutable scroll for collecting debug prophecies

### 🎯 Locator Spells

Locators are your targeting spells for finding UI elements in the digital realm:

```swift
let locator = Locator(
    criteria: [
        "AXRole": "AXButton",
        "AXTitle": "Save Document"
    ],
    requireAction: "AXPress"  // Ensure the element can be commanded
)
```

### 📜 Prophecy Format

All spells return visions in the form of `HandlerResponse`:

```swift
public struct HandlerResponse {
    public var data: AXElement?        // The summoned element's essence
    public var error: String?          // Curse description if spell failed
    public var debug_logs: [String]?   // Scrying logs and mystical insights
}
```

### 🔮 Element Essence Structure

The harvested element data contains:

```swift
public struct AXElement {
    public var attributes: [String: AnyCodable]  // Mystical element properties
    public var path: [String]                    // Journey from app realm to element
}
```

## 🖥️ Command Line Grimoire

The `axorc` familiar accepts JSON incantations through multiple mystical channels:

### 📥 Invocation Methods

```bash
# Channel through the ethereal STDIN
echo '{"command": "ping", "command_id": "1"}' | axorc --stdin

# Read from a spell scroll (file)
axorc --file command.json

# Direct magical utterance
axorc '{"command": "ping", "command_id": "1"}'
```

### 🎭 Available Enchantments

- `ping`: Test the spiritual connection
- `getFocusedElement`: Divine the currently focused element
- `getAttributes`: Extract element properties using locator magic
- `query`: Summon elements matching your desires
- `describeElement`: Reveal comprehensive element mysteries
- `performAction`: Command elements to do your bidding
- `extractText`: Harvest textual essence from the digital realm
- `batch`: Execute multiple rituals in sequence
- `collectAll`: Gather all matching elements from the UI cosmos

### 📋 Example Incantation

```json
{
  "command_id": "summon_back_button",
  "command": "query", 
  "application": "Safari",
  "locator": {
    "criteria": {
      "AXRole": "AXButton",
      "AXTitle": "Back"
    }
  },
  "attributes": ["AXRole", "AXTitle", "AXEnabled"]
}
```

## 🔐 Mystical Permissions

AXorcist requires sacred accessibility permissions to commune with the UI spirits. macOS will present you with a permission ritual upon first use, or you may grant access manually through:

**System Preferences → Security & Privacy → Privacy → Accessibility**

*Grant AXorcist the power it needs to serve your digital dominion!*

## 🔨 Forging Your Arsenal

```bash
# Forge the mystical artifacts
make build

# Test the enchantments (requires local machine - CI spirits cannot grant accessibility permissions)
make test

# Complete ritual: build and test
make all

# Purify the workspace
make clean
```

### 🌙 Testing in the Shadows

The test rituals require accessibility permissions to commune with the UI spirits—permissions that cannot be granted automatically on CI. While automated build specters can verify your Swift incantations compile correctly, the full test ceremonies must be performed on a local machine where you can manually grant the sacred accessibility permissions through System Preferences.

*The spirits of continuous integration watch over your builds, but only mortal hands can unlock the accessibility gates.*

## ⚔️ Minimum Requirements

- macOS 13.0 or later (The realm of Ventura and beyond)
- Swift 5.9 or later (Modern Swift sorcery)
- Xcode 15.0 or later (For apprentice developers)

## 🤝 Join the Coven

1. Fork this mystical repository
2. Create your feature branch (`git checkout -b feature/amazing-spell`)
3. Craft your enhancements
4. Add tests for new magical abilities
5. Ensure all enchantments pass (`make test`)
6. Submit a pull request to the main grimoire

## 📜 Sacred License

MIT License - see [LICENSE](LICENSE) scroll for the complete binding agreement.

## 🌟 Allied Magical Artifacts

- [AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot) - iOS accessibility testing spells
- [Marathon](https://github.com/MarathonLabs/marathon) - Cross-platform test execution rituals  
- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon) - Lua-powered macOS automation sorcery

---

<!-- Testing CI workflow -->

<p align="center">
  <em>May your UI elements bend to your will, and may your accessibility spells never fail. 🧙‍♂️✨</em>
</p>