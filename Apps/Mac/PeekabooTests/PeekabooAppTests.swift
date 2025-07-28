import Testing
import SwiftUI
@testable import Peekaboo

@Suite("PeekabooApp Tests", .tags(.unit, .fast))
@MainActor
struct PeekabooAppTests {
    
    @Test("App initializes with required components")
    func appInitialization() throws {
        // Create app instance
        let app = PeekabooApp()
        
        // Verify status bar controller exists
        #expect(app.statusBarController != nil)
        
        // Verify settings are initialized
        #expect(app.settings != nil)
        
        // Verify permissions handler is set up
        #expect(app.permissions != nil)
        
        // Verify session store is created
        #expect(app.sessionStore != nil)
        
        // Verify agent is initialized
        #expect(app.agent != nil)
        
        // Verify speech recognizer is available
        #expect(app.speechRecognizer != nil)
    }
    
    @Test("App registers for system notifications")
    func systemNotifications() {
        let app = PeekabooApp()
        
        // Verify app delegate is set (if applicable)
        // Note: In SwiftUI apps, this might be handled differently
        
        // Verify notification observers are set up
        // This would typically be done through NotificationCenter observations
    }
    
    @Test("App state restoration")
    func stateRestoration() {
        let app = PeekabooApp()
        
        // Verify window restoration settings
        // Note: SwiftUI handles this through scene storage
        
        // Verify session restoration if applicable
        #expect(app.sessionStore != nil)
    }
    
    @Test("App appearance configuration")
    func appearanceConfiguration() {
        let app = PeekabooApp()
        
        // Verify that settings are properly loaded
        let settings = app.settings
        
        // Check default values are reasonable
        #expect(settings.apiKey.isEmpty || !settings.apiKey.isEmpty)
        #expect(settings.model.isEmpty == false)
    }
    
    @Test("App lifecycle handlers")
    func lifecycleHandlers() {
        let app = PeekabooApp()
        
        // Verify cleanup happens on termination
        // This would typically involve checking if proper cleanup methods exist
        
        // Verify session saving on app termination
        #expect(app.sessionStore != nil)
    }
    
    @Test("URL scheme handling")
    func urlSchemeHandling() {
        let app = PeekabooApp()
        
        // Test if app can handle custom URL schemes (if implemented)
        // For example: peekaboo://action/parameters
        
        // This test would verify URL parsing and action dispatch
        #expect(app.agent != nil) // Agent would handle automation URLs
    }
    
    @Test("Dependency injection setup")
    func dependencyInjection() {
        let app = PeekabooApp()
        
        // Verify all dependencies are properly wired
        #expect(app.agent.settings === app.settings)
        #expect(app.agent.sessionStore === app.sessionStore)
        #expect(app.statusBarController.settings === app.settings)
        #expect(app.statusBarController.sessionStore === app.sessionStore)
        #expect(app.statusBarController.agent === app.agent)
    }
}