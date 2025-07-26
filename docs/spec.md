# Peekaboo Menu Bar App Specification

## Overview

Transform the Peekaboo app into a sophisticated menu bar application that serves as an AI-powered macOS automation assistant. The app will live in the menu bar, allowing users to interact through voice or text to automate tasks on their Mac, with full visibility into what the AI agent is doing.

## Core Features

### 1. Menu Bar Interface
- **Icon**: Ghost icon (Peekaboo mascot) in the menu bar
- **Left-click**: Opens rich view with chat/voice interface
- **Right-click**: Shows context menu with quick actions
- **Status Indicator**: Visual feedback when agent is working (animated ghost, badge, etc.)

### 2. Interaction Modes
- **Voice Mode**: Simple interface with big talk button using modern Apple Speech APIs
- **Chat Mode**: Text-based interaction for complex commands
- **Session Persistence**: Continuous conversation context across interactions

### 3. Agent Integration
- **OpenAI Chat Completions API**: Primary AI backend with function calling and streaming
- **Tool Execution**: Full suite of automation tools (click, type, screenshot, etc.)
- **Real-time Feedback**: Show what the agent is thinking and doing
- **Visual Verification**: Display screenshots with element annotations

### 4. Session Details View
- **Execution Timeline**: Step-by-step view of agent actions
- **Tool Calls**: Detailed view of each tool invocation with parameters
- **Success/Failure Status**: Clear indicators for each action
- **Agent Reasoning**: Show the agent's thought process
- **Screenshots**: Visual history of what the agent saw

### 5. Element Inspector Integration
- **Interactive Screenshots**: Click on screenshots to see element details
- **Hover Annotations**: Show accessibility information on hover
- **Element Highlighting**: Visual indicators for interactive elements
- **Accessibility Tree**: Optional detailed view of UI structure

### 6. Settings & Configuration
- **API Keys**: Secure storage for OpenAI/Ollama keys
- **Launch on Startup**: System integration preferences
- **Debug Panel**: Logs, network requests, and troubleshooting
- **Model Selection**: Choose between different AI providers/models

## Architecture

### Project Structure

```
Peekaboo/
├── PeekabooCore/                    # Shared framework
│   ├── Agent/                       # Agent logic from CLI
│   │   ├── OpenAIAgent.swift
│   │   ├── AgentTypes.swift
│   │   ├── AgentFunctions.swift
│   │   └── AgentNetworking.swift
│   ├── AI/                          # AI provider abstraction
│   │   ├── AIProvider.swift
│   │   ├── OpenAIProvider.swift
│   │   └── OllamaProvider.swift
│   ├── Commands/                    # Command implementations
│   │   ├── CommandProtocol.swift
│   │   ├── SeeCommand.swift
│   │   ├── ClickCommand.swift
│   │   └── ... (other commands)
│   ├── Session/                     # Session management
│   │   ├── SessionManager.swift
│   │   ├── SessionCache.swift
│   │   └── SessionTypes.swift
│   ├── UI/                          # Shared UI components
│   │   ├── ElementOverlay/
│   │   ├── OverlayManager.swift
│   │   └── UIElementTypes.swift
│   └── Utilities/                   # Common utilities
│       ├── AXorcistExtensions.swift
│       ├── Logging.swift
│       └── Configuration.swift
│
├── GUI/Peekaboo/                    # Main menu bar app
│   ├── App/
│   │   ├── PeekabooApp.swift      # App entry point
│   │   ├── AppDelegate.swift      # Lifecycle management
│   │   └── StatusBarController.swift
│   ├── Views/
│   │   ├── MainView/              # Primary interaction view
│   │   │   ├── ChatView.swift
│   │   │   ├── VoiceView.swift
│   │   │   └── SessionView.swift
│   │   ├── Details/               # Session details window
│   │   │   ├── TimelineView.swift
│   │   │   ├── ToolCallView.swift
│   │   │   └── ScreenshotView.swift
│   │   ├── Settings/              # Settings window
│   │   │   ├── SettingsView.swift
│   │   │   ├── APIKeysView.swift
│   │   │   └── DebugView.swift
│   │   └── Inspector/             # Element inspection
│   │       ├── InspectorView.swift
│   │       └── ElementDetailsView.swift
│   ├── Services/
│   │   ├── AgentService.swift     # Agent coordination
│   │   ├── SpeechService.swift    # Voice integration
│   │   ├── SessionService.swift   # Session management
│   │   └── PermissionService.swift
│   └── Resources/
│       └── Assets.xcassets        # Icons, images
│
├── peekaboo-cli/                    # Existing CLI (modified)
│   └── Sources/peekaboo/
│       └── main.swift             # CLI entry point
│
└── PeekabooInspector/              # Existing inspector (shared components)
```

### Component Architecture

#### 1. **PeekabooCore Framework**
Shared Swift package containing all reusable logic:
- Agent execution engine (extracted from CLI)
- Command implementations with direct function calls
- Session management with GUI-friendly callbacks
- UI element detection and overlay components
- Configuration and logging utilities

#### 2. **Service Layer Architecture**
Following VibeTunnel patterns:
```swift
@MainActor
final class AgentService: ObservableObject {
    static let shared = AgentService()
    @Published var isExecuting = false
    @Published var currentSession: Session?
    // ...
}
```

#### 3. **Window Management**
Multi-window support using WindowGroup:
- Main window (chat/voice interface)
- Settings window
- Session details window
- Inspector window (optional)

#### 4. **State Management**
Modern SwiftUI patterns:
- @StateObject for service instances
- @EnvironmentObject for app-wide state
- @Observable for model objects
- Avoid unnecessary ViewModels

### Key Integration Points

#### 1. **Agent Execution**
- Replace CLI process spawning with direct function calls
- Use `AgentInternalExecutor` pattern for in-app execution
- Add progress delegates for real-time UI updates
- Implement cancellation support

#### 2. **Session Visualization**
- Transform CLI JSON output to rich UI models
- Add timeline visualization for step-by-step execution
- Integrate screenshot capture with element annotations
- Store sessions in Core Data for history

#### 3. **Voice Integration**
```swift
import Speech
import AVFoundation

class SpeechService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcription = ""
    // Modern Speech framework integration
}
```

#### 4. **Element Inspector Integration**
- Reuse `OverlayManager` logic for element detection
- Adapt `ElementOverlay` views for screenshot annotation
- Add interactive element selection on screenshots
- Show accessibility tree on demand

## Implementation Phases

### Phase 1: Foundation (Week 1)
1. **Setup PeekabooCore Framework**
   - Extract agent logic from CLI
   - Create shared command implementations
   - Setup basic project structure

2. **Basic Menu Bar App**
   - StatusBarController implementation
   - Basic window management
   - Settings infrastructure

### Phase 2: Core Features (Week 2)
1. **Agent Integration**
   - Wire up OpenAI Chat Completions API
   - Implement execution callbacks
   - Basic session management

2. **Primary UI**
   - Chat interface
   - Simple voice button
   - Real-time status updates

### Phase 3: Advanced Features (Week 3)
1. **Session Details**
   - Timeline visualization
   - Tool call details
   - Screenshot viewer

2. **Inspector Integration**
   - Element overlay on screenshots
   - Hover interactions
   - Accessibility details

### Phase 4: Polish (Week 4)
1. **Voice Integration**
   - Full speech recognition
   - Natural language processing
   - Voice feedback

2. **Final Polish**
   - Ghost icon and animations
   - Performance optimization
   - Error handling
   - Documentation

## Technical Considerations

### 1. **Performance**
- Lazy loading of screenshots
- Efficient session storage
- Background processing for AI calls
- Smooth animations at 60fps

### 2. **Security**
- Secure API key storage in Keychain
- Permission handling for accessibility/screen recording
- Sandboxing considerations

### 3. **Error Handling**
- Graceful degradation
- User-friendly error messages
- Retry mechanisms
- Offline support

### 4. **Testing Strategy**
- Unit tests for PeekabooCore
- UI tests for critical flows
- Integration tests with test host app
- Performance benchmarks

## Design Guidelines

### 1. **Visual Design**
- Follow Apple HIG
- Consistent with system appearance
- Light/dark mode support
- Subtle animations

### 2. **User Experience**
- Immediate feedback for all actions
- Clear progress indicators
- Cancellable operations
- Keyboard shortcuts

### 3. **Accessibility**
- Full VoiceOver support
- Keyboard navigation
- High contrast mode
- Reduced motion support

## Success Metrics

1. **Performance**: < 100ms UI response time
2. **Reliability**: 99.9% uptime for core features
3. **Usability**: Complete task in < 3 interactions
4. **Quality**: < 0.1% crash rate

## Future Enhancements

1. **Plugin System**: Allow third-party tool additions
2. **Shortcuts Integration**: Native Shortcuts app support
3. **Multi-Model Support**: Claude, local models, etc.
4. **Team Features**: Shared automations and templates
5. **Analytics**: Usage insights and optimization suggestions

## Dependencies

### External
- **AXorcist**: Accessibility API wrapper
- **OpenAI Swift**: API client (or native implementation)
- **Sparkle**: Auto-update framework

### System
- macOS 14.0+ (for latest SwiftUI features)
- Swift 5.9+
- Xcode 15+

## Development Timeline

- **Week 1**: Foundation and basic menu bar app
- **Week 2**: Agent integration and core UI
- **Week 3**: Advanced features and inspector
- **Week 4**: Voice, polish, and release prep

Total estimated time: 4 weeks for MVP