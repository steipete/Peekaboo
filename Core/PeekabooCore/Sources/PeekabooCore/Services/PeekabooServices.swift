import Foundation

/// Main entry point for all Peekaboo services
/// Provides a unified interface for screen capture, automation, and management operations
public final class PeekabooServices: Sendable {
    /// Shared instance for convenience
    public static let shared = PeekabooServices()
    
    /// Screen capture operations
    public let screenCapture: ScreenCaptureServiceProtocol
    
    /// Application and window queries
    public let applications: ApplicationServiceProtocol
    
    /// UI automation operations
    public let automation: UIAutomationServiceProtocol
    
    /// Window management operations
    public let windows: WindowManagementServiceProtocol
    
    /// Menu interaction operations
    public let menus: MenuServiceProtocol
    
    /// Session management
    public let sessions: SessionManagerProtocol
    
    /// Initialize with default service implementations
    public init() {
        self.screenCapture = ScreenCaptureService()
        self.applications = ApplicationService()
        self.automation = UIAutomationService()
        self.windows = WindowManagementService()
        self.menus = MenuService()
        self.sessions = SessionManager()
    }
    
    /// Initialize with custom service implementations (for testing)
    public init(
        screenCapture: ScreenCaptureServiceProtocol,
        applications: ApplicationServiceProtocol,
        automation: UIAutomationServiceProtocol,
        windows: WindowManagementServiceProtocol,
        menus: MenuServiceProtocol,
        sessions: SessionManagerProtocol
    ) {
        self.screenCapture = screenCapture
        self.applications = applications
        self.automation = automation
        self.windows = windows
        self.menus = menus
        self.sessions = sessions
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
        // Capture the image
        let captureResult: CaptureResult
        switch target {
        case .screen(let index):
            captureResult = try await screenCapture.captureScreen(displayIndex: index)
        case .window(let app, let index):
            captureResult = try await screenCapture.captureWindow(appIdentifier: app, windowIndex: index)
        case .frontmost:
            captureResult = try await screenCapture.captureFrontmost()
        case .area(let rect):
            captureResult = try await screenCapture.captureArea(rect)
        }
        
        // TODO: Integrate with AI providers from CLI
        // For now, return a placeholder result
        return CaptureAnalysisResult(
            captureResult: captureResult,
            question: question,
            answer: "AI analysis not yet implemented in Core",
            provider: provider ?? "none"
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
        // Create a new session
        let sessionId = try await sessions.createSession()
        
        // Capture initial state
        let captureResult = try await screenCapture.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: nil
        )
        
        // Detect elements
        let detectionResult = try await automation.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId
        )
        
        // Store in session
        try await sessions.storeDetectionResult(sessionId: sessionId, result: detectionResult)
        
        // Execute actions
        var executedActions: [ExecutedAction] = []
        
        for action in actions {
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
                        sessionId: sessionId
                    )
                    
                case .hotkey(let keys):
                    try await automation.hotkey(keys: keys, holdDuration: 100)
                    
                case .wait(let milliseconds):
                    try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                }
                
                executedActions.append(ExecutedAction(
                    action: action,
                    success: true,
                    duration: Date().timeIntervalSince(startTime),
                    error: nil
                ))
            } catch {
                executedActions.append(ExecutedAction(
                    action: action,
                    success: false,
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                ))
                throw error
            }
        }
        
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