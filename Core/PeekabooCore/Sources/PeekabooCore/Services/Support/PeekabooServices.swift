import Foundation
import os.log
import Tachikoma

/**
 * Central service registry and coordination hub for all Peekaboo functionality.
 *
 * `PeekabooServices` is the main entry point for accessing all Peekaboo capabilities including
 * screen capture, UI automation, window management, and AI-powered operations. It provides
 * a unified interface that coordinates between different service implementations and manages
 * their lifecycle.
 *
 * ## Architecture Overview
 * PeekabooServices follows a service locator pattern where individual services are:
 * - **Injected at initialization**: All services are provided via dependency injection
 * - **Protocol-based**: Services implement specific protocols for testability
 * - **Thread-safe**: All services can be safely accessed from multiple threads
 * - **Stateless where possible**: Most services maintain minimal state
 *
 * ## Core Service Categories
 * - **Capture Services**: Screen capture, window capture, region capture
 * - **Automation Services**: Click, type, scroll, hotkey operations
 * - **Management Services**: Window, application, and session management
 * - **AI Services**: Model providers and intelligent automation agents
 *
 * ## Usage Example
 * ```swift
 * // Access the shared instance
 * let services = PeekabooServices.shared
 *
 * // Capture a screenshot
 * let screenshot = try await services.screenCapture.captureScreen()
 *
 * // Perform UI automation
 * try await services.automation.click(target: .coordinate(100, 200))
 *
 * // Use AI agent for complex tasks
 * if let agent = services.agent {
 *     let result = try await agent.executeTask("Click the submit button")
 * }
 * ```
 *
 * ## Dependency Injection
 * For testing or custom configurations, services can be injected:
 * ```swift
 * let customServices = PeekabooServices(
 *     screenCapture: MockScreenCaptureService(),
 *     automation: MockAutomationService(),
 *     // ... other services
 * )
 * ```
 *
 * - Important: All services run on the main thread due to macOS UI automation requirements
 * - Note: The shared instance is automatically configured with production services
 * - Since: PeekabooCore 1.0.0
 */
public final class PeekabooServices: @unchecked Sendable {
    /// Shared instance for convenient access in typical usage scenarios
    @MainActor
    public static let shared = PeekabooServices.createShared()

    /// Internal logger for debugging service initialization and coordination
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "Services")

    /// Centralized logging service for consistent logging across all Peekaboo components
    public let logging: LoggingServiceProtocol

    /// Screen and window capture service supporting ScreenCaptureKit and legacy APIs
    public let screenCapture: ScreenCaptureServiceProtocol

    /// Application discovery and enumeration service for finding running apps and windows
    public let applications: ApplicationServiceProtocol

    /// Core UI automation service for mouse, keyboard, and accessibility interactions
    public let automation: UIAutomationServiceProtocol

    /// Window management service for positioning, resizing, and organizing windows
    public let windows: WindowManagementServiceProtocol

    /// Menu bar interaction service for navigating application menus
    public let menu: MenuServiceProtocol

    /// macOS Dock interaction service for launching and managing Dock items
    public let dock: DockServiceProtocol

    /// System dialog interaction service for handling alerts, file dialogs, etc.
    public let dialogs: DialogServiceProtocol

    /// Session and state management for automation workflows and history
    public let sessions: SessionManagerProtocol

    /// File system operations service for reading, writing, and manipulating files
    public let files: FileServiceProtocol

    /// Configuration management for user preferences and API keys
    public let configuration: ConfigurationManager

    /// Process execution service for running shell commands and scripts
    public let process: ProcessServiceProtocol

    /// Permissions verification service for checking macOS privacy permissions
    public let permissions: PermissionsService

    /// AI model provider for accessing configured language models (OpenAI, Anthropic, etc.)
    public let modelProvider: AIModelProvider

    /// Intelligent automation agent service for natural language task execution
    public private(set) var agent: AgentServiceProtocol?

    /// Screen management service for multi-monitor support
    public let screens: ScreenServiceProtocol

    /// Lock for thread-safe agent updates
    private let agentLock = NSLock()

    /// Initialize with default service implementations
    @MainActor
    public init(modelProvider: AIModelProvider? = nil) {
        self.logger.info("🚀 Initializing PeekabooServices with default implementations")

        let logging = LoggingService()
        self.logger.debug("✅ LoggingService initialized")

        let apps = ApplicationService()
        self.logger.debug("✅ ApplicationService initialized")

        let sess = SessionManager()
        self.logger.debug("✅ SessionManager initialized")

        let screenCap = ScreenCaptureService(loggingService: logging)
        self.logger.debug("✅ ScreenCaptureService initialized")

        let auto = UIAutomationService(sessionManager: sess, loggingService: logging)
        self.logger.debug("✅ UIAutomationService initialized")

        let windows = WindowManagementService(applicationService: apps)
        self.logger.debug("✅ WindowManagementService initialized")

        let menuSvc = MenuService(applicationService: apps)
        self.logger.debug("✅ MenuService initialized")

        let dockSvc = DockService()
        self.logger.debug("✅ DockService initialized")

        let screenSvc = ScreenService()
        self.logger.debug("✅ ScreenService initialized")

        self.logging = logging
        self.screenCapture = screenCap
        self.applications = apps
        self.automation = auto
        self.windows = windows
        self.menu = menuSvc
        self.dock = dockSvc
        self.screens = screenSvc

        self.dialogs = DialogService()
        self.logger.debug("✅ DialogService initialized")

        self.sessions = sess

        self.files = FileService()
        self.logger.debug("✅ FileService initialized")

        self.configuration = ConfigurationManager.shared
        self.logger.debug("✅ ConfigurationManager initialized")

        self.process = ProcessService(
            applicationService: apps,
            screenCaptureService: screenCap,
            sessionManager: sess,
            uiAutomationService: auto,
            windowManagementService: windows,
            menuService: menuSvc,
            dockService: dockSvc)
        self.logger.debug("✅ ProcessService initialized")

        self.permissions = PermissionsService()
        self.logger.debug("✅ PermissionsService initialized")

        // Set model provider (default to empty if not provided)
        self.modelProvider = modelProvider ?? AIModelProvider()
        self.logger.debug("✅ AIModelProvider initialized")

        // Agent service will be initialized by createShared method
        self.agent = nil

        self.logger.info("✨ PeekabooServices initialization complete")
    }

    /// Initialize with custom service implementations (for testing)
    @MainActor
    public init(
        logging: LoggingServiceProtocol? = nil,
        screenCapture: ScreenCaptureServiceProtocol,
        applications: ApplicationServiceProtocol,
        automation: UIAutomationServiceProtocol,
        windows: WindowManagementServiceProtocol,
        menu: MenuServiceProtocol,
        dock: DockServiceProtocol,
        dialogs: DialogServiceProtocol,
        sessions: SessionManagerProtocol,
        files: FileServiceProtocol,
        process: ProcessServiceProtocol,
        permissions: PermissionsService? = nil,
        agent: AgentServiceProtocol? = nil,
        configuration: ConfigurationManager? = nil,
        screens: ScreenServiceProtocol? = nil,
        modelProvider: AIModelProvider? = nil)
    {
        self.logger.info("🚀 Initializing PeekabooServices with custom implementations")
        self.logging = logging ?? LoggingService()
        self.screenCapture = screenCapture
        self.applications = applications
        self.automation = automation
        self.windows = windows
        self.menu = menu
        self.dock = dock
        self.dialogs = dialogs
        self.sessions = sessions
        self.files = files
        self.process = process
        self.permissions = permissions ?? PermissionsService()
        self.agent = agent
        self.configuration = configuration ?? ConfigurationManager.shared
        self.screens = screens ?? ScreenService()
        self.modelProvider = modelProvider ?? AIModelProvider()

        self.logger.info("✨ PeekabooServices initialization complete (custom)")
    }

    /// Internal initializer that takes all services including agent
    private init(
        logging: LoggingServiceProtocol,
        screenCapture: ScreenCaptureServiceProtocol,
        applications: ApplicationServiceProtocol,
        automation: UIAutomationServiceProtocol,
        windows: WindowManagementServiceProtocol,
        menu: MenuServiceProtocol,
        dock: DockServiceProtocol,
        dialogs: DialogServiceProtocol,
        sessions: SessionManagerProtocol,
        files: FileServiceProtocol,
        process: ProcessServiceProtocol,
        permissions: PermissionsService,
        configuration: ConfigurationManager,
        agent: AgentServiceProtocol?,
        screens: ScreenServiceProtocol,
        modelProvider: AIModelProvider)
    {
        self.logging = logging
        self.screenCapture = screenCapture
        self.applications = applications
        self.automation = automation
        self.windows = windows
        self.menu = menu
        self.dock = dock
        self.dialogs = dialogs
        self.sessions = sessions
        self.files = files
        self.process = process
        self.permissions = permissions
        self.configuration = configuration
        self.agent = agent
        self.screens = screens
        self.modelProvider = modelProvider
    }

    /// Create the shared instance with proper initialization order
    @MainActor
    private static func createShared() -> PeekabooServices {
        let logger = Logger(subsystem: "boo.peekaboo.core", category: "Services")
        logger.info("🚀 Creating shared PeekabooServices instance")

        let logging = LoggingService()
        let apps = ApplicationService()
        let sess = SessionManager()
        let screenCap = ScreenCaptureService(loggingService: logging)
        let auto = UIAutomationService(sessionManager: sess, loggingService: logging)
        let windows = WindowManagementService(applicationService: apps)
        let menuSvc = MenuService(applicationService: apps)
        let dockSvc = DockService()
        let dialogs = DialogService()
        let files = FileService()
        let config = ConfigurationManager.shared
        let permissions = PermissionsService()
        let screens = ScreenService()
        let process = ProcessService(
            applicationService: apps,
            screenCaptureService: screenCap,
            sessionManager: sess,
            uiAutomationService: auto,
            windowManagementService: windows,
            menuService: menuSvc,
            dockService: dockSvc)

        // Create AI service
        let aiService = PeekabooAIService()
        logger.debug("✅ AI service initialized")

        // Create services instance first
        let services = PeekabooServices(
            logging: logging,
            screenCapture: screenCap,
            applications: apps,
            automation: auto,
            windows: windows,
            menu: menuSvc,
            dock: dockSvc,
            dialogs: dialogs,
            sessions: sess,
            files: files,
            process: process,
            permissions: permissions,
            configuration: config,
            agent: nil,
            screens: screens)

        // Note: AI model provider is created later from environment in createShared

        // Now create agent service if any API key is available
        // Check for OpenAI, Anthropic, or Ollama availability
        let agent: AgentServiceProtocol?
        let hasOpenAI = config.getOpenAIAPIKey() != nil && !config.getOpenAIAPIKey()!.isEmpty
        let hasAnthropic = config.getAnthropicAPIKey() != nil && !config.getAnthropicAPIKey()!.isEmpty
        let hasOllama = true // Ollama doesn't require API key

        if hasOpenAI || hasAnthropic || hasOllama {
            let agentConfig = config.getConfiguration()
            let providers = config.getAIProviders()
            let isEnvironmentProvided = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] != nil

            logger.debug("🔍 AI Providers from config: '\(providers)'")
            logger
                .debug(
                    "🔍 Environment PEEKABOO_AI_PROVIDERS: '\(ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] ?? "not set")'")
            logger.debug("🔍 Has OpenAI: \(hasOpenAI), Has Anthropic: \(hasAnthropic), Has Ollama: \(hasOllama)")

            // Determine default model using the parser with conflict detection
            let determination = ProviderParser.determineDefaultModelWithConflict(
                from: providers,
                hasOpenAI: hasOpenAI,
                hasAnthropic: hasAnthropic,
                hasOllama: hasOllama,
                configuredDefault: agentConfig?.agent?.defaultModel,
                isEnvironmentProvided: isEnvironmentProvided)

            logger.debug("🔍 Determined default model: '\(determination.model)'")

            // Print conflict warning if needed
            if determination.hasConflict {
                logger.warning("⚠️ Model configuration conflict detected:")
                logger.warning("   Config file specifies: \(determination.configModel ?? "none")")
                logger.warning("   Environment variable specifies: \(determination.environmentModel ?? "none")")
                logger.warning("   Using environment variable: \(determination.model)")

                // Also print to stdout so user sees it as a warning
                print("""
                ⚠️  Model configuration conflict:
                   Config (~/.peekaboo/config.json) specifies: \(determination.configModel ?? "none")
                   PEEKABOO_AI_PROVIDERS environment variable specifies: \(determination.environmentModel ?? "none")
                   → Using environment variable: \(determination.model)
                """)
            }

            // Create AI model provider from environment
            let modelProvider = try? AIConfiguration.fromEnvironment()
            agent = PeekabooAgentService(
                services: services,
                modelProvider: modelProvider ?? AIModelProvider(),
                defaultModelName: determination.model)
            logger.debug("✅ PeekabooAgentService initialized with available providers")
        } else {
            agent = nil
            logger.debug("⚠️ PeekabooAgentService skipped - no API keys found for any provider")
        }

        // Create default model provider for the instance
        let defaultModelProvider = (try? AIConfiguration.fromEnvironment()) ?? AIModelProvider()
        
        // Return services with agent
        return PeekabooServices(
            logging: logging,
            screenCapture: screenCap,
            applications: apps,
            automation: auto,
            windows: windows,
            menu: menuSvc,
            dock: dockSvc,
            dialogs: dialogs,
            sessions: sess,
            files: files,
            process: process,
            permissions: permissions,
            configuration: config,
            agent: agent,
            screens: screens,
            modelProvider: defaultModelProvider)
    }

    /// Refresh the agent service when API keys change
    @MainActor
    public func refreshAgentService() {
        self.logger.info("🔄 Refreshing agent service with updated configuration")

        // Reload configuration to get latest API keys
        _ = self.configuration.loadConfiguration()

        // Check for available API keys
        let hasOpenAI = self.configuration.getOpenAIAPIKey() != nil && !self.configuration.getOpenAIAPIKey()!.isEmpty
        let hasAnthropic = self.configuration.getAnthropicAPIKey() != nil && !self.configuration.getAnthropicAPIKey()!
            .isEmpty
        let hasOllama = true // Ollama doesn't require API key

        if hasOpenAI || hasAnthropic || hasOllama {
            let agentConfig = self.configuration.getConfiguration()
            let providers = self.configuration.getAIProviders()

            // Determine default model based on first available provider
            var defaultModel = agentConfig?.agent?.defaultModel
            if defaultModel == nil {
                if providers.contains("anthropic"), hasAnthropic {
                    defaultModel = "claude-opus-4-20250514"
                } else if providers.contains("openai"), hasOpenAI {
                    defaultModel = "gpt-4.1"
                } else if providers.contains("ollama") {
                    defaultModel = "llava:latest"
                }
            }

            self.agentLock.lock()
            defer { agentLock.unlock() }

            self.agent = PeekabooAgentService(
                services: self,
                modelProvider: self.modelProvider,
                defaultModelName: defaultModel ?? "claude-opus-4-20250514")
            self.logger.info("✅ Agent service refreshed with providers: \(providers)")
        } else {
            self.agentLock.lock()
            defer { agentLock.unlock() }

            self.agent = nil
            self.logger.warning("⚠️ No API keys available - agent service disabled")
        }
    }
}

/// High-level convenience methods
extension PeekabooServices {
    // REMOVED: captureAndAnalyze method - AI analysis should be done through the agent service

    /// Perform UI automation with automatic session management
    /// - Parameters:
    ///   - appIdentifier: Target application
    ///   - actions: Automation actions to perform
    /// - Returns: Automation result
    public func automate(
        appIdentifier: String,
        actions: [AutomationAction]) async throws -> AutomationResult
    {
        self.logger.info("🤖 Starting automation for app: \(appIdentifier)")
        self.logger.debug("Number of actions: \(actions.count)")

        // Create a new session
        let sessionId = try await sessions.createSession()
        self.logger.debug("Created session: \(sessionId)")

        // Capture initial state
        self.logger.debug("Capturing initial window state")
        let captureResult = try await screenCapture.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: nil)

        // Detect elements
        self.logger.debug("Detecting UI elements")
        let windowContext = WindowContext(
            applicationName: captureResult.metadata.applicationInfo?.name,
            windowTitle: captureResult.metadata.windowInfo?.title,
            windowBounds: captureResult.metadata.windowInfo?.bounds)
        let detectionResult = try await automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId,
            windowContext: windowContext)
        self.logger.info("Detected \(detectionResult.elements.all.count) elements")

        // Store in session
        try await self.sessions.storeDetectionResult(sessionId: sessionId, result: detectionResult)

        // Execute actions
        var executedActions: [ExecutedAction] = []

        for (index, action) in actions.enumerated() {
            self.logger.info("Executing action \(index + 1)/\(actions.count): \(String(describing: action))")
            let startTime = Date()
            do {
                switch action {
                case let .click(target, clickType):
                    try await self.automation.click(
                        target: target,
                        clickType: clickType,
                        sessionId: sessionId)

                case let .type(text, target, clear):
                    try await self.automation.type(
                        text: text,
                        target: target,
                        clearExisting: clear,
                        typingDelay: 50,
                        sessionId: sessionId)

                case let .scroll(direction, amount, target):
                    try await self.automation.scroll(
                        direction: direction,
                        amount: amount,
                        target: target,
                        smooth: false,
                        delay: 10, // 10ms between scroll ticks
                        sessionId: sessionId)

                case let .hotkey(keys):
                    try await self.automation.hotkey(keys: keys, holdDuration: 100)

                case let .wait(milliseconds):
                    try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                }

                let duration = Date().timeIntervalSince(startTime)
                self.logger.debug("✅ Action completed in \(String(format: "%.2f", duration))s")

                executedActions.append(ExecutedAction(
                    action: action,
                    success: true,
                    duration: duration,
                    error: nil))
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                let peekabooError = error.asPeekabooError(context: "Action execution failed")
                self.logger
                    .error(
                        "❌ Action failed after \(String(format: "%.2f", duration))s: \(peekabooError.localizedDescription)")

                executedActions.append(ExecutedAction(
                    action: action,
                    success: false,
                    duration: duration,
                    error: peekabooError.localizedDescription))
                throw peekabooError
            }
        }

        self.logger
            .info(
                "✅ Automation complete: \(executedActions.count(where: { $0.success }))/\(executedActions.count) actions succeeded")

        return AutomationResult(
            sessionId: sessionId,
            actions: executedActions,
            initialScreenshot: captureResult.savedPath)
    }
}

/// Target for capture operations
public enum CaptureTarget: Sendable {
    case screen(index: Int?)
    case window(app: String, index: Int?)
    case frontmost
    case area(CGRect)
}

// REMOVED: CaptureAnalysisResult - AI analysis should be done through the agent service

/// Automation action
public enum AutomationAction: Sendable {
    case click(target: ClickTarget, type: ClickType)
    case type(text: String, target: String?, clear: Bool)
    case scroll(direction: ScrollDirection, amount: Int, target: String?)
    case hotkey(keys: String)
    case wait(milliseconds: Int)
}

/// Result of automation
public struct AutomationResult: Sendable {
    public let sessionId: String
    public let actions: [ExecutedAction]
    public let initialScreenshot: String?
}

/// An executed action with result
public struct ExecutedAction: Sendable {
    public let action: AutomationAction
    public let success: Bool
    public let duration: TimeInterval
    public let error: String?
}
