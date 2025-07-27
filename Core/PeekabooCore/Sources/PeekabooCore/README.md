# PeekabooCore Structure

This directory contains the core functionality of Peekaboo, organized into logical modules for better maintainability.

## Directory Overview

### 📁 Core/
Core types, models, and shared utilities used throughout the codebase.

- **Errors/** - Unified error handling system
  - `PeekabooError.swift` - Main error enumeration
  - `ErrorFormatting.swift` - Error display and formatting
  - `ErrorRecovery.swift` - Error recovery strategies
  
- **Models/** - Domain models
  - `Application.swift` - Application and window information
  - `Capture.swift` - Screen capture results and metadata
  - `Session.swift` - UI automation session data
  - `Window.swift` - Window focus and element information
  
- **Utilities/** - Shared utilities and helpers
  - `CorrelationID.swift` - Request correlation tracking

### 📁 AI/
AI integration layer with support for multiple providers.

- **Core/** - AI abstractions and interfaces
  - `ModelInterface.swift` - Common protocol for all AI models
  - `MessageTypes.swift` - Unified message format
  - `StreamingTypes.swift` - Streaming response handling
  - `ModelProvider.swift` - Provider enumeration and factory
  
- **Providers/** - AI provider implementations
  - **OpenAI/** - GPT-4, o3, o4 models
  - **Anthropic/** - Claude 3, 3.5, 4 models
  - **Grok/** - xAI Grok models
  - **Ollama** - Local model support
  
- **Agent/** - Agent framework for task automation
  - **Core/** - Agent definition and configuration
  - **Execution/** - Agent runtime and session management
  - **Tools/** - Tool definitions for agent capabilities

### 📁 Services/
Service layer providing high-level functionality.

- **Core/** - Service protocols defining interfaces
  
- **System/** - System-level services
  - `ApplicationService.swift` - App launching and management
  - `ProcessService.swift` - Process control
  - `FileService.swift` - File operations
  
- **UI/** - UI automation services
  - `UIAutomationService.swift` - Basic UI automation
  - `UIAutomationServiceEnhanced.swift` - Advanced UI detection
  - `WindowManagementService.swift` - Window control
  - `MenuService.swift` - Menu interaction
  - `DialogService.swift` - Dialog handling
  - `DockService.swift` - Dock interaction
  
- **Capture/** - Screen capture services
  - `ScreenCaptureService.swift` - Screenshot and element detection
  
- **Agent/** - Agent-specific services
  - `PeekabooAgentService.swift` - Main agent service
  - `Tools/` - Modular tool implementations
  
- **Support/** - Supporting services
  - `LoggingService.swift` - Centralized logging
  - `SessionManager.swift` - Session persistence
  - `PeekabooServices.swift` - Service container

### 📁 Configuration/
Application configuration and settings.

- `Configuration.swift` - Configuration models
- `ConfigurationManager.swift` - Config file management
- `AIProviderParser.swift` - AI provider string parsing

## Key Concepts

### Service Container
The `PeekabooServices` class provides a centralized container for all services, enabling dependency injection and easy testing.

### Error Handling
All errors flow through the unified `PeekabooError` type, providing consistent error handling with recovery suggestions.

### AI Provider Abstraction
The `ModelInterface` protocol allows seamless switching between AI providers while maintaining a consistent API.

### Tool-based Architecture
The agent system uses a modular tool-based approach, where each tool encapsulates a specific capability (e.g., clicking, typing, taking screenshots).

## Usage Example

```swift
// Initialize services
let services = PeekabooServices.shared

// Take a screenshot
let result = try await services.screenCapture.captureScreen()

// Launch an app
try await services.application.launchApplication(name: "Safari")

// Execute an agent task
let agentService = PeekabooAgentService()
let result = try await agentService.executeTask("Click on the Submit button")
```