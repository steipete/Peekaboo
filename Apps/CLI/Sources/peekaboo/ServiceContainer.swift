import Foundation
import PeekabooCore

/// Container for managing service instances
@available(macOS 14.0, *)
class ServiceContainer {
    static let shared = try! ServiceContainer()
    
    let applicationService: ApplicationServiceProtocol
    let screenCaptureService: ScreenCaptureServiceProtocol
    let sessionManager: SessionManagerProtocol
    let uiAutomationService: UIAutomationServiceProtocol
    let windowManagementService: WindowManagementServiceProtocol
    let menuService: MenuServiceProtocol
    let dockService: DockServiceProtocol
    let processService: ProcessServiceProtocol
    
    private init() throws {
        // Initialize all services
        self.applicationService = ApplicationService()
        self.screenCaptureService = ScreenCaptureService()
        self.sessionManager = SessionManager()
        self.uiAutomationService = UIAutomationServiceEnhanced()
        self.windowManagementService = WindowManagementService()
        self.menuService = MenuService()
        self.dockService = DockService()
        
        // Initialize ProcessService with all dependencies
        self.processService = ProcessService(
            applicationService: applicationService,
            screenCaptureService: screenCaptureService,
            sessionManager: sessionManager,
            uiAutomationService: uiAutomationService,
            windowManagementService: windowManagementService,
            menuService: menuService,
            dockService: dockService
        )
    }
}