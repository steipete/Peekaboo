# Peekaboo Architecture Overview

This document provides a high-level overview of how Tachikoma and PeekabooCore work together to provide AI-powered macOS automation capabilities.

## System Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Tachikoma     │    │  PeekabooCore   │    │ PeekabooVisualizer│
│  AI Framework  │◄───┤ Automation Core │◄───┤ Visual Feedback │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Dependency Flow

**Tachikoma** (AI Model Management)
- Provides `AIModelProvider` for dependency injection
- Manages OpenAI, Anthropic, Grok, and Ollama models
- Handles API configuration and credential management

**PeekabooCore** (Automation Engine)
- Uses Tachikoma's `AIModelProvider` for intelligent automation
- Provides specialized services for UI interaction
- Manages sessions, screen capture, and accessibility APIs

**PeekabooVisualizer** (Feedback System)
- Provides real-time visual feedback for automation operations
- Integrates with all PeekabooCore services for user feedback

## Tachikoma: AI Model Management

### Architecture Pattern: Dependency Injection

Tachikoma has migrated from a singleton pattern to dependency injection for better testability and flexibility:

```swift
// Old (deprecated)
let model = try await Tachikoma.shared.getModel("gpt-4.1")

// New (recommended)
let provider = try AIConfiguration.fromEnvironment()
let model = try provider.getModel("gpt-4.1")
```

### Key Components

#### AIModelProvider
- **Role**: Central registry for AI model instances
- **Pattern**: Immutable collection with functional updates
- **Thread Safety**: Full concurrent access support

#### AIModelFactory
- **Role**: Factory methods for creating model instances
- **Supported Providers**: OpenAI, Anthropic, Grok (xAI), Ollama
- **Configuration**: Handles API keys, base URLs, and model-specific parameters

#### AIConfiguration
- **Role**: Environment-based automatic configuration
- **Sources**: Environment variables and `~/.tachikoma/credentials` file
- **Auto-Discovery**: Automatically registers all available models

## PeekabooCore: Automation Engine

### Architecture Pattern: Service Orchestration

PeekabooCore uses a service locator pattern with specialized service delegation:

```swift
let services = PeekabooServices.shared
let automation = services.automation  // UIAutomationService
let screenCapture = services.screenCapture  // ScreenCaptureService
let applications = services.applications  // ApplicationService
```

### Service Hierarchy

#### PeekabooServices (Service Locator)
- **Role**: Central registry for all automation services
- **Pattern**: Service locator with dependency injection support
- **Lifecycle**: Manages service initialization and coordination

#### UIAutomationService (Orchestrator)
- **Role**: Primary automation interface delegating to specialized services
- **Delegation**: Routes operations to appropriate specialized services
- **Session Management**: Maintains state across automation workflows

#### Specialized Services
Each service handles a specific aspect of automation:

- **ClickService**: Mouse interaction and element targeting
- **TypeService**: Keyboard input and text manipulation
- **ScreenCaptureService**: Display and window capture
- **ApplicationService**: Application discovery and management
- **WindowManagementService**: Window positioning and state control
- **MenuService**: Menu bar navigation and interaction
- **SessionManager**: State persistence and element caching

### Threading Model

**Main Thread Requirement**: All UI automation operations run on MainActor due to macOS requirements:

```swift
@MainActor
public final class UIAutomationService: UIAutomationServiceProtocol {
    // All operations are main-thread bound
}
```

### Integration Points

#### AI Integration
PeekabooCore integrates with Tachikoma through `PeekabooAgentService`:

```swift
let modelProvider = try AIConfiguration.fromEnvironment()
let agent = PeekabooAgentService(
    services: PeekabooServices.shared,
    modelProvider: modelProvider
)
```

#### Visual Feedback Integration
Services automatically connect to PeekabooVisualizer when available:

```swift
// Automatic visualizer integration
let visualizerClient = VisualizationClient.shared
_ = await visualizerClient.showClickFeedback(at: clickPoint, type: clickType)
```

## Data Flow Architecture

### Automation Workflow

1. **Input**: Natural language task or direct API call
2. **AI Processing**: `PeekabooAgentService` uses Tachikoma models
3. **Service Orchestration**: `UIAutomationService` delegates to specialized services
4. **Platform Integration**: Services use macOS APIs (Accessibility, ScreenCaptureKit)
5. **Visual Feedback**: Operations trigger visualizer animations
6. **Session Management**: State cached for subsequent operations

### Example Flow: "Click the Submit button"

```
User Input ("Click Submit")
    ↓
PeekabooAgentService (AI interpretation)
    ↓
UIAutomationService.detectElements() → ElementDetectionService
    ↓
UIAutomationService.click() → ClickService
    ↓
macOS Accessibility APIs
    ↓
VisualizationClient (click animation)
```

## Performance Characteristics

### Service Performance Ranges
- **Element Detection**: 200-800ms (AI analysis + accessibility correlation)
- **Click Operations**: 10-50ms (accessibility API optimization)
- **Screen Capture**: 20-100ms (ScreenCaptureKit acceleration)
- **Application Discovery**: 20-200ms (depending on system load)
- **Window Management**: 10-200ms (depending on operation complexity)

### Optimization Strategies
- **Session Caching**: Element detection results cached per session
- **Accessibility Timeouts**: Reduced from 6s to 2s to prevent hangs
- **Dual APIs**: Modern ScreenCaptureKit with CGWindowList fallback
- **Visual Feedback**: Async animations don't block automation operations

## Error Handling Strategy

### Layered Error Handling
1. **Service Level**: Individual services handle API-specific errors
2. **Orchestration Level**: UIAutomationService provides unified error handling
3. **Agent Level**: AI agent handles retry logic and error recovery
4. **Client Level**: Applications receive structured error information

### Defensive Programming
- **Permission Validation**: Automatic checks for Screen Recording and Accessibility permissions
- **Timeout Protection**: Configurable timeouts prevent system hangs
- **Graceful Degradation**: Fallback strategies for problematic applications
- **State Validation**: Element existence and accessibility verification

## Configuration Management

### Multi-Source Configuration
1. **Environment Variables**: `PEEKABOO_AI_PROVIDERS`, `OPENAI_API_KEY`, etc.
2. **Credential Files**: `~/.peekaboo/config.json`, `~/.tachikoma/credentials`
3. **Runtime Parameters**: Method-level configuration overrides
4. **Feature Flags**: `PEEKABOO_USE_MODERN_CAPTURE`, etc.

### Configuration Precedence
```
CLI Arguments > Environment Variables > Credential Files > Config Files > Defaults
```

## Future Architecture Considerations

### Scalability
- Service architecture supports horizontal scaling through additional specialized services
- AI model provider supports multiple concurrent model instances
- Session management designed for multi-user and multi-process scenarios

### Extensibility
- Plugin architecture possible through service locator pattern
- AI model provider supports custom model implementations
- Visual feedback system can be extended with additional visualization types

### Cross-Platform Potential
- Service interfaces abstract platform-specific implementations
- Threading model adaptable to other platforms
- AI integration remains platform-agnostic

---

*This architecture has been designed to be "really easy for other people to understand" while providing the performance and reliability needed for production automation workflows.*