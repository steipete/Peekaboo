import Algorithms
import Darwin
import Foundation
import os.log
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooAutomation
import PeekabooFoundation
import PeekabooVisualizer
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
 * // Access a default instance
 * let services = PeekabooServices()
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
@MainActor
public final class PeekabooServices {
    /// Internal logger for debugging service initialization and coordination
    private let logger = SystemLogger(subsystem: "boo.peekaboo.core", category: "Services")

    /// Centralized logging service for consistent logging across all Peekaboo components
    public let logging: any LoggingServiceProtocol

    /// Screen and window capture service supporting ScreenCaptureKit and legacy APIs
    public let screenCapture: any ScreenCaptureServiceProtocol

    /// Application discovery and enumeration service for finding running apps and windows
    public let applications: any ApplicationServiceProtocol

    /// Core UI automation service for mouse, keyboard, and accessibility interactions
    public let automation: any PeekabooAutomation.UIAutomationServiceProtocol

    /// Window management service for positioning, resizing, and organizing windows
    public let windows: any WindowManagementServiceProtocol

    /// Menu bar interaction service for navigating application menus
    public let menu: any MenuServiceProtocol

    /// macOS Dock interaction service for launching and managing Dock items
    public let dock: any DockServiceProtocol

    /// System dialog interaction service for handling alerts, file dialogs, etc.
    public let dialogs: any DialogServiceProtocol

    /// Session and state management for automation workflows and history
    public let sessions: any SessionManagerProtocol

    /// File system operations service for reading, writing, and manipulating files
    public let files: any FileServiceProtocol

    /// Configuration management for user preferences and API keys
    public let configuration: ConfigurationManager

    /// Process execution service for running shell commands and scripts
    public let process: any ProcessServiceProtocol

    /// Permissions verification service for checking macOS privacy permissions
    public let permissions: PermissionsService

    /// Audio input service for recording and transcription
    public let audioInput: AudioInputService

    // Model provider is now handled internally by Tachikoma

    /// Intelligent automation agent service for natural language task execution
    public private(set) var agent: (any AgentServiceProtocol)?

    /// Screen management service for multi-monitor support
    public let screens: any ScreenServiceProtocol

    /// Lock for thread-safe agent updates
    private let agentLock = NSLock()

    /// Initialize with default service implementations
    @MainActor
    public init() {
        self.logger.debug("🚀 Initializing PeekabooServices with default implementations")

        let logging = LoggingService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) LoggingService initialized")

        let apps = ApplicationService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) ApplicationService initialized")

        let sess = SessionManager()
        self.logger.debug("\(AgentDisplayTokens.Status.success) SessionManager initialized")

        let screenCap = ScreenCaptureService(loggingService: logging)
        self.logger.debug("\(AgentDisplayTokens.Status.success) ScreenCaptureService initialized")

        let auto = UIAutomationService(sessionManager: sess, loggingService: logging, searchPolicy: .balanced)
        self.logger.debug("\(AgentDisplayTokens.Status.success) UIAutomationService initialized")

        let windows = WindowManagementService(applicationService: apps)
        self.logger.debug("\(AgentDisplayTokens.Status.success) WindowManagementService initialized")

        let menuSvc = MenuService(applicationService: apps)
        self.logger.debug("\(AgentDisplayTokens.Status.success) MenuService initialized")

        let dockSvc = DockService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) DockService initialized")

        let screenSvc = ScreenService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) ScreenService initialized")

        self.logging = logging
        self.screenCapture = screenCap
        self.applications = apps
        self.automation = auto
        self.windows = windows
        self.menu = menuSvc
        self.dock = dockSvc
        self.screens = screenSvc

        self.dialogs = DialogService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) DialogService initialized")

        self.sessions = sess

        self.files = FileService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) FileService initialized")

        self.configuration = ConfigurationManager.shared
        self.logger.debug("\(AgentDisplayTokens.Status.success) ConfigurationManager initialized")

        self.process = ProcessService(
            applicationService: apps,
            screenCaptureService: screenCap,
            sessionManager: sess,
            uiAutomationService: auto,
            windowManagementService: windows,
            menuService: menuSvc,
            dockService: dockSvc)
        self.logger.debug("\(AgentDisplayTokens.Status.success) ProcessService initialized")

        self.permissions = PermissionsService()
        self.logger.debug("\(AgentDisplayTokens.Status.success) PermissionsService initialized")

        // Initialize AI service for audio/transcription features
        let aiService = PeekabooAIService()
        self.audioInput = AudioInputService(aiService: aiService)
        self.logger.debug("\(AgentDisplayTokens.Status.success) AudioInputService initialized")

        // Model provider is now handled internally by Tachikoma

        // Agent service will be initialized by createShared method
        self.agent = nil

        self.logger.debug("✨ PeekabooServices initialization complete")
        self.refreshAgentService()
    }

    /// Initialize with custom service implementations (for testing)
    @MainActor
    public init(
        logging: (any LoggingServiceProtocol)? = nil,
        screenCapture: any ScreenCaptureServiceProtocol,
        applications: any ApplicationServiceProtocol,
        automation: any PeekabooAutomation.UIAutomationServiceProtocol,
        windows: any WindowManagementServiceProtocol,
        menu: any MenuServiceProtocol,
        dock: any DockServiceProtocol,
        dialogs: any DialogServiceProtocol,
        sessions: any SessionManagerProtocol,
        files: any FileServiceProtocol,
        process: any ProcessServiceProtocol,
        permissions: PermissionsService? = nil,
        audioInput: AudioInputService? = nil,
        agent: (any AgentServiceProtocol)? = nil,
        configuration: ConfigurationManager? = nil,
        screens: (any ScreenServiceProtocol)? = nil)
    {
        self.logger.debug("🚀 Initializing PeekabooServices with custom implementations")
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
        self.audioInput = audioInput ?? AudioInputService(aiService: PeekabooAIService())
        self.agent = agent
        self.configuration = configuration ?? ConfigurationManager.shared
        self.screens = screens ?? ScreenService()
        // Model provider is now handled internally by Tachikoma

        self.logger.debug("✨ PeekabooServices initialization complete (custom)")
    }

    /// Internal initializer that takes all services including agent
    private init(
        logging: any LoggingServiceProtocol,
        screenCapture: any ScreenCaptureServiceProtocol,
        applications: any ApplicationServiceProtocol,
        automation: any PeekabooAutomation.UIAutomationServiceProtocol,
        windows: any WindowManagementServiceProtocol,
        menu: any MenuServiceProtocol,
        dock: any DockServiceProtocol,
        dialogs: any DialogServiceProtocol,
        sessions: any SessionManagerProtocol,
        files: any FileServiceProtocol,
        process: any ProcessServiceProtocol,
        permissions: PermissionsService,
        audioInput: AudioInputService,
        configuration: ConfigurationManager,
        agent: (any AgentServiceProtocol)?,
        screens: any ScreenServiceProtocol)
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
        self.audioInput = audioInput
        self.configuration = configuration
        self.agent = agent
        self.screens = screens
        // Model provider is now handled internally by Tachikoma
    }

    /// Create the shared instance with proper initialization order
    private static func logModelConflict(_ determination: ModelDetermination, logger: SystemLogger) {
        logger.warning("\(AgentDisplayTokens.Status.warning) Model configuration conflict detected.")
        logger.warning("   Config file specifies: \(determination.configModel ?? "none")")
        logger.warning("   Environment variable specifies: \(determination.environmentModel ?? "none")")
        logger.warning("   Using environment variable: \(determination.model)")

        let warningMessage = """
        \(AgentDisplayTokens.Status.warning)  Model configuration conflict:
           Config (~/.peekaboo/config.json) specifies: \(determination.configModel ?? "none")
           PEEKABOO_AI_PROVIDERS environment variable specifies: \(determination.environmentModel ?? "none")
           → Using environment variable: \(determination.model)
        """
        print(warningMessage)
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
        let hasOllama = false

        if hasOpenAI || hasAnthropic || hasOllama {
            let agentConfig = self.configuration.getConfiguration()
            let providers = self.configuration.getAIProviders()
            let environmentProviders = EnvironmentVariables.value(for: "PEEKABOO_AI_PROVIDERS")

            let sources = ModelSources(
                providers: providers,
                hasOpenAI: hasOpenAI,
                hasAnthropic: hasAnthropic,
                hasOllama: hasOllama,
                configuredDefault: agentConfig?.agent?.defaultModel,
                isEnvironmentProvided: environmentProviders != nil)

            let determination = self.determineDefaultModelWithConflict(sources)
            if determination.hasConflict {
                Self.logModelConflict(determination, logger: self.logger)
            }

            self.agentLock.lock()
            defer { agentLock.unlock() }

            do {
                let languageModel = Self.parseModelStringForAgent(determination.model)
                self.agent = try PeekabooAgentService(
                    services: self,
                    defaultModel: languageModel)
            } catch {
                self.logger.error("Failed to refresh PeekabooAgentService: \(error)")
                self.agent = nil
            }
            self.logger
                .info("\(AgentDisplayTokens.Status.success) Agent service refreshed with providers: \(providers)")
        } else {
            self.agentLock.lock()
            defer { agentLock.unlock() }

            self.agent = nil
            self.logger.warning("\(AgentDisplayTokens.Status.warning) No API keys available - agent service disabled")
        }
    }
}

extension PeekabooServices: PeekabooServiceProviding {}

private enum EnvironmentVariables {
    static func value(for key: String) -> String? {
        guard let raw = getenv(key) else { return nil }
        return String(cString: raw)
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
        self.logger.info("\(AgentDisplayTokens.Status.running) Starting automation for app: \(appIdentifier)")
        self.logger.debug("Number of actions: \(actions.count)")

        let preparation = try await prepareAutomationSession(appIdentifier: appIdentifier)
        let executedActions = try await executeAutomationActions(actions, sessionId: preparation.sessionId)

        let successCount = executedActions.count(where: { $0.success })
        let summary = "\(AgentDisplayTokens.Status.success) Automation complete: "
            + "\(successCount)/\(executedActions.count) actions succeeded"
        self.logger.info("\(summary)")

        return AutomationResult(
            sessionId: preparation.sessionId,
            actions: executedActions,
            initialScreenshot: preparation.initialScreenshot)
    }

    private func prepareAutomationSession(appIdentifier: String) async throws -> AutomationPreparation {
        let sessionId = try await sessions.createSession()
        self.logger.debug("Created session: \(sessionId)")

        self.logger.debug("Capturing initial window state")
        let captureResult = try await screenCapture.captureWindow(appIdentifier: appIdentifier, windowIndex: nil)

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
        try await self.sessions.storeDetectionResult(sessionId: sessionId, result: detectionResult)

        return AutomationPreparation(sessionId: sessionId, initialScreenshot: captureResult.savedPath)
    }

    private func executeAutomationActions(
        _ actions: [AutomationAction],
        sessionId: String) async throws -> [ExecutedAction]
    {
        var executedActions: [ExecutedAction] = []

        for (index, action) in actions.indexed() {
            self.logger
                .info("Executing action \(index + 1)/\(actions.count): \(String(describing: action), privacy: .public)")
            let startTime = Date()
            do {
                try await self.performAutomationAction(action, sessionId: sessionId)
                let duration = Date().timeIntervalSince(startTime)
                let successMessage =
                    "\(AgentDisplayTokens.Status.success) Action completed in " +
                    "\(self.formatDuration(duration))s"
                self.logger.debug("\(successMessage, privacy: .public)")

                executedActions.append(ExecutedAction(
                    action: action,
                    success: true,
                    duration: duration,
                    error: nil))
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                let peekabooError = error.asPeekabooError(context: "Action execution failed")
                let failureMessage =
                    "\(AgentDisplayTokens.Status.failure) Action failed after " +
                    "\(self.formatDuration(duration))s: \(peekabooError.localizedDescription)"
                self.logger.error("\(failureMessage, privacy: .public)")

                executedActions.append(ExecutedAction(
                    action: action,
                    success: false,
                    duration: duration,
                    error: peekabooError.localizedDescription))
                throw peekabooError
            }
        }

        return executedActions
    }

    private func performAutomationAction(_ action: AutomationAction, sessionId: String) async throws {
        switch action {
        case let .click(target, clickType):
            try await self.automation.click(target: target, clickType: clickType, sessionId: sessionId)
        case let .type(text, target, clear):
            try await self.automation.type(
                text: text,
                target: target,
                clearExisting: clear,
                typingDelay: 50,
                sessionId: sessionId)
        case let .scroll(direction, amount, target):
            let request = ScrollRequest(
                direction: direction,
                amount: amount,
                target: target,
                smooth: false,
                delay: 10,
                sessionId: sessionId)
            try await automation.scroll(request)
        case let .hotkey(keys):
            try await self.automation.hotkey(keys: keys, holdDuration: 100)
        case let .wait(milliseconds):
            try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        String(format: "%.2f", interval)
    }

    // MARK: - Private Helper Methods

    /// Parse model string to LanguageModel enum
    private static func parseModelStringForAgent(_ modelString: String) -> LanguageModel {
        // Parse model string to LanguageModel enum
        LanguageModel.parse(from: modelString) ?? .openai(.gpt51)
    }

    private func determineDefaultModelWithConflict(_ sources: ModelSources) -> ModelDetermination {
        let components = sources.providers
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let environmentModel = components.first?.split(separator: "/").last.map(String.init)

        let hasConflict = sources.isEnvironmentProvided
            && sources.configuredDefault != nil
            && sources.configuredDefault != environmentModel

        let model: String = if !sources.providers.isEmpty {
            environmentModel ?? "gpt-5.1"
        } else if let configuredDefault = sources.configuredDefault {
            configuredDefault
        } else if sources.hasAnthropic {
            "claude-sonnet-4.5"
        } else if sources.hasOpenAI {
            "gpt-5.1"
        } else if sources.hasOllama {
            "gpt-5.1"
        } else {
            "gpt-5.1"
        }

        return ModelDetermination(
            model: model,
            hasConflict: hasConflict,
            configModel: sources.configuredDefault,
            environmentModel: environmentModel)
    }
}

/// Result of model determination with conflict detection
struct ModelDetermination {
    let model: String
    let hasConflict: Bool
    let configModel: String?
    let environmentModel: String?
}

private struct ModelSources {
    let providers: String
    let hasOpenAI: Bool
    let hasAnthropic: Bool
    let hasOllama: Bool
    let configuredDefault: String?
    let isEnvironmentProvided: Bool
}

private struct AutomationPreparation {
    let sessionId: String
    let initialScreenshot: String?
}

private typealias SystemLogger = os.Logger
