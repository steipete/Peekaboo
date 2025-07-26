import Foundation
import os.log

/// Main entry point for all Peekaboo services
/// Provides a unified interface for screen capture, automation, and management operations
public final class PeekabooServices: Sendable {
    /// Shared instance for convenience
    public static let shared = PeekabooServices()
    
    /// Logger for service initialization and operations
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "Services")
    
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
    
    /// AI provider service for image analysis
    public let aiProvider: AIProviderServiceProtocol
    
    /// Agent service for AI-powered automation
    public let agent: AgentServiceProtocol?
    
    /// Initialize with default service implementations
    public init() {
        logger.info("🚀 Initializing PeekabooServices with default implementations")
        
        let logging = LoggingService()
        logger.debug("✅ LoggingService initialized")
        
        let apps = ApplicationService()
        logger.debug("✅ ApplicationService initialized")
        
        let sess = SessionManager()
        logger.debug("✅ SessionManager initialized")
        
        let screenCap = ScreenCaptureService(loggingService: logging)
        logger.debug("✅ ScreenCaptureService initialized")
        
        let auto = UIAutomationService(sessionManager: sess)
        logger.debug("✅ UIAutomationService initialized")
        
        let windows = WindowManagementService(applicationService: apps)
        logger.debug("✅ WindowManagementService initialized")
        
        let menuSvc = MenuService(applicationService: apps)
        logger.debug("✅ MenuService initialized")
        
        let dockSvc = DockService()
        logger.debug("✅ DockService initialized")
        
        self.logging = logging
        self.screenCapture = screenCap
        self.applications = apps
        self.automation = auto
        self.windows = windows
        self.menu = menuSvc
        self.dock = dockSvc
        
        self.dialogs = DialogService()
        logger.debug("✅ DialogService initialized")
        
        self.sessions = sess
        
        self.files = FileService()
        logger.debug("✅ FileService initialized")
        
        self.configuration = ConfigurationManager.shared
        logger.debug("✅ ConfigurationManager initialized")
        
        self.process = ProcessService(
            applicationService: apps,
            screenCaptureService: screenCap,
            sessionManager: sess,
            uiAutomationService: auto,
            windowManagementService: windows,
            menuService: menuSvc,
            dockService: dockSvc
        )
        logger.debug("✅ ProcessService initialized")
        
        self.aiProvider = AIProviderService()
        logger.debug("✅ AIProviderService initialized")
        
        // Agent service is optional - only create if API key is available
        // TODO: Fix actor isolation issue
        self.agent = nil
        /*
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let toolExecutor = PeekabooToolExecutor(verbose: false)
            self.agent = OpenAIAgentService(
                apiKey: apiKey,
                model: "gpt-4.1",
                verbose: false,
                maxSteps: 20,
                toolExecutor: toolExecutor
            )
            logger.debug("✅ OpenAIAgentService initialized")
        } else {
            self.agent = nil
            logger.debug("⚠️ OpenAIAgentService skipped - no OPENAI_API_KEY")
        }
        */
        
        logger.info("✨ PeekabooServices initialization complete")
    }
    
    /// Initialize with custom service implementations (for testing)
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
        aiProvider: AIProviderServiceProtocol? = nil,
        agent: AgentServiceProtocol? = nil,
        configuration: ConfigurationManager? = nil
    ) {
        logger.info("🚀 Initializing PeekabooServices with custom implementations")
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
        self.aiProvider = aiProvider ?? AIProviderService()
        self.agent = agent
        self.configuration = configuration ?? ConfigurationManager.shared
        
        logger.info("✨ PeekabooServices initialization complete (custom)")
    }
}

/// High-level convenience methods
extension PeekabooServices {
    /// Capture and analyze in one operation
    /// - Parameters:
    ///   - target: What to capture
    ///   - question: Question to ask about the image
    ///   - provider: AI provider to use (nil = auto-select)
    /// - Returns: Analysis result with image and answer
    public func captureAndAnalyze(
        target: CaptureTarget,
        question: String,
        provider: String? = nil
    ) async throws -> CaptureAnalysisResult {
        logger.info("📸 Starting capture and analyze operation")
        logger.debug("Target: \(String(describing: target)), Question: \(question)")
        
        // Capture the image
        let captureResult: CaptureResult
        switch target {
        case .screen(let index):
            logger.debug("Capturing screen at index: \(index ?? 0)")
            captureResult = try await screenCapture.captureScreen(displayIndex: index)
        case .window(let app, let index):
            logger.debug("Capturing window for app: \(app), index: \(index ?? 0)")
            captureResult = try await screenCapture.captureWindow(appIdentifier: app, windowIndex: index)
        case .frontmost:
            logger.debug("Capturing frontmost window")
            captureResult = try await screenCapture.captureFrontmost()
        case .area(let rect):
            logger.debug("Capturing area: x=\(rect.origin.x), y=\(rect.origin.y), width=\(rect.size.width), height=\(rect.size.height)")
            captureResult = try await screenCapture.captureArea(rect)
        }
        
        logger.info("✅ Capture complete: \(captureResult.savedPath ?? "<unsaved>")")
        
        // Analyze the image if a path is available
        guard let imagePath = captureResult.savedPath else {
            throw PeekabooError.captureFailed("No saved path available for analysis")
        }
        
        // Perform AI analysis
        let analysisResult = try await aiProvider.analyzeImage(
            at: imagePath,
            prompt: question
        )
        
        logger.info("✅ Analysis complete using \(analysisResult.provider)/\(analysisResult.model)")
        
        return CaptureAnalysisResult(
            captureResult: captureResult,
            question: question,
            answer: analysisResult.analysis,
            provider: "\(analysisResult.provider)/\(analysisResult.model)"
        )
    }
    
    /// Perform UI automation with automatic session management
    /// - Parameters:
    ///   - appIdentifier: Target application
    ///   - actions: Automation actions to perform
    /// - Returns: Automation result
    public func automate(
        appIdentifier: String,
        actions: [AutomationAction]
    ) async throws -> AutomationResult {
        logger.info("🤖 Starting automation for app: \(appIdentifier)")
        logger.debug("Number of actions: \(actions.count)")
        
        // Create a new session
        let sessionId = try await sessions.createSession()
        logger.debug("Created session: \(sessionId)")
        
        // Capture initial state
        logger.debug("Capturing initial window state")
        let captureResult = try await screenCapture.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: nil
        )
        
        // Detect elements
        logger.debug("Detecting UI elements")
        let detectionResult = try await automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId
        )
        logger.info("Detected \(detectionResult.elements.all.count) elements")
        
        // Store in session
        try await sessions.storeDetectionResult(sessionId: sessionId, result: detectionResult)
        
        // Execute actions
        var executedActions: [ExecutedAction] = []
        
        for (index, action) in actions.enumerated() {
            logger.info("Executing action \(index + 1)/\(actions.count): \(String(describing: action))")
            let startTime = Date()
            do {
                switch action {
                case .click(let target, let clickType):
                    try await automation.click(
                        target: target,
                        clickType: clickType,
                        sessionId: sessionId
                    )
                    
                case .type(let text, let target, let clear):
                    try await automation.type(
                        text: text,
                        target: target,
                        clearExisting: clear,
                        typingDelay: 50,
                        sessionId: sessionId
                    )
                    
                case .scroll(let direction, let amount, let target):
                    try await automation.scroll(
                        direction: direction,
                        amount: amount,
                        target: target,
                        smooth: false,
                        delay: 10,  // 10ms between scroll ticks
                        sessionId: sessionId
                    )
                    
                case .hotkey(let keys):
                    try await automation.hotkey(keys: keys, holdDuration: 100)
                    
                case .wait(let milliseconds):
                    try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                logger.debug("✅ Action completed in \(String(format: "%.2f", duration))s")
                
                executedActions.append(ExecutedAction(
                    action: action,
                    success: true,
                    duration: duration,
                    error: nil
                ))
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.error("❌ Action failed after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
                
                executedActions.append(ExecutedAction(
                    action: action,
                    success: false,
                    duration: duration,
                    error: error.localizedDescription
                ))
                throw error
            }
        }
        
        logger.info("✅ Automation complete: \(executedActions.filter { $0.success }.count)/\(executedActions.count) actions succeeded")
        
        return AutomationResult(
            sessionId: sessionId,
            actions: executedActions,
            initialScreenshot: captureResult.savedPath
        )
    }
}

/// Target for capture operations
public enum CaptureTarget: Sendable {
    case screen(index: Int?)
    case window(app: String, index: Int?)
    case frontmost
    case area(CGRect)
}

/// Result of capture and analysis
public struct CaptureAnalysisResult: Sendable {
    public let captureResult: CaptureResult
    public let question: String
    public let answer: String
    public let provider: String
}

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