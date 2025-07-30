import Foundation
import os.log

/// Main entry point for all Peekaboo services
/// Provides a unified interface for screen capture, automation, and management operations
public final class PeekabooServices: @unchecked Sendable {
    /// Shared instance for convenience
    @MainActor
    public static let shared = PeekabooServices.createShared()

    /// Logger for service initialization and operations
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "Services")

    /// Unified logging service
    public let logging: LoggingServiceProtocol

    /// Screen capture operations
    public let screenCapture: ScreenCaptureServiceProtocol

    /// Application and window queries
    public let applications: ApplicationServiceProtocol

    /// UI automation operations
    public let automation: UIAutomationServiceProtocol

    /// Window management operations
    public let windows: WindowManagementServiceProtocol

    /// Menu interaction operations
    public let menu: MenuServiceProtocol

    /// Dock interaction operations
    public let dock: DockServiceProtocol

    /// Dialog interaction operations
    public let dialogs: DialogServiceProtocol

    /// Session management
    public let sessions: SessionManagerProtocol

    /// File system operations
    public let files: FileServiceProtocol

    /// Configuration management
    public let configuration: ConfigurationManager

    /// Process/script execution service
    public let process: ProcessServiceProtocol

    /// Permissions checking service
    public let permissions: PermissionsService

    /// Agent service for AI-powered automation
    public private(set) var agent: AgentServiceProtocol?

    /// Audio input service for voice commands and audio transcription
    public let audioInput: AudioInputServiceProtocol

    /// Lock for thread-safe agent updates
    private let agentLock = NSLock()

    /// Initialize with default service implementations
    @MainActor
    public init() {
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

        self.logging = logging
        self.screenCapture = screenCap
        self.applications = apps
        self.automation = auto
        self.windows = windows
        self.menu = menuSvc
        self.dock = dockSvc

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

        // Agent service will be initialized by createShared method
        self.agent = nil

        // Audio input service needs AI service, so temporarily initialize with placeholder
        // Will be properly initialized in createShared with actual AI service
        self.audioInput = AudioInputService(aiService: PeekabooAIService())
        self.logger.debug("✅ AudioInputService initialized (placeholder)")

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
        audioInput: AudioInputServiceProtocol? = nil)
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
        self.audioInput = audioInput ?? AudioInputService(aiService: PeekabooAIService())

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
        audioInput: AudioInputServiceProtocol)
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
        self.audioInput = audioInput
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
        let process = ProcessService(
            applicationService: apps,
            screenCaptureService: screenCap,
            sessionManager: sess,
            uiAutomationService: auto,
            windowManagementService: windows,
            menuService: menuSvc,
            dockService: dockSvc)

        // Create AI service and audio service
        let aiService = PeekabooAIService()
        let audioInput = AudioInputService(aiService: aiService)
        logger.debug("✅ AudioInputService initialized")

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
            audioInput: audioInput)

        // Initialize ModelProvider with available API keys
        Task {
            do {
                try await ModelProvider.shared.setupFromEnvironment()
                logger.debug("✅ ModelProvider initialized from environment")
            } catch {
                let peekabooError = error.asPeekabooError(context: "Failed to setup ModelProvider")
                logger.error("⚠️ ModelProvider setup failed: \(peekabooError.localizedDescription)")
            }
        }

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
            let determination = AIProviderParser.determineDefaultModelWithConflict(
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

            agent = PeekabooAgentService(
                services: services,
                defaultModelName: determination.model)
            logger.debug("✅ PeekabooAgentService initialized with available providers")
        } else {
            agent = nil
            logger.debug("⚠️ PeekabooAgentService skipped - no API keys found for any provider")
        }

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
            audioInput: audioInput)
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
