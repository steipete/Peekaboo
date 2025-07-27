import AppKit
import Foundation
import SwiftUI

/// Helper to open the Settings window programmatically.
///
/// This utility provides a workaround for opening Settings in MenuBarExtra apps
/// where the standard Settings scene might not work properly.
@MainActor
enum SettingsOpener {
    /// SwiftUI's hardcoded settings window identifier
    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"
    
    /// Opens the Settings window using the environment action via notification
    /// This is needed for cases where we can't use SettingsLink (e.g., from menu bar)
    static func openSettings() {
        // Let DockIconManager handle dock visibility
        DockIconManager.shared.temporarilyShowDock()
        
        Task { @MainActor in
            // Small delay to ensure dock icon is visible
            try? await Task.sleep(for: .milliseconds(50))
            
            // Activate the app
            NSApp.activate(ignoringOtherApps: true)
            
            // Use notification approach
            NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            
            // Wait for window to appear
            try? await Task.sleep(for: .milliseconds(100))
            
            // Find and bring settings window to front
            if let settingsWindow = findSettingsWindow() {
                // Center the window on active screen
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowFrame = settingsWindow.frame
                    let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
                    let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
                    settingsWindow.setFrameOrigin(NSPoint(x: x, y: y))
                }
                
                // Ensure window is visible and in front
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
                
                // Temporarily raise window level to ensure it's on top
                settingsWindow.level = .floating
                
                // Reset level after a short delay
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    settingsWindow.level = .normal
                    
                    // DockIconManager will handle dock visibility automatically
                }
            }
        }
    }
    
    /// Finds the settings window using multiple detection methods
    static func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            // Check by identifier
            if window.identifier?.rawValue == settingsWindowIdentifier {
                return true
            }
            
            // Check by title
            if window.isVisible && window.styleMask.contains(.titled) &&
                (window.title.localizedCaseInsensitiveContains("settings") ||
                 window.title.localizedCaseInsensitiveContains("preferences"))
            {
                return true
            }
            
            // Check by content view controller type
            if let contentVC = window.contentViewController,
               String(describing: type(of: contentVC)).contains("Settings")
            {
                return true
            }
            
            return false
        }
    }
}

// MARK: - Hidden Window View

/// A minimal hidden window that enables Settings to work in MenuBarExtra apps.
///
/// This is a workaround for FB10184971. The window remains invisible and serves
/// only to enable the Settings command in apps that use MenuBarExtra as their
/// primary interface without a main window.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    openSettings()
                }
            }
            .onAppear {
                // Hide this window from the dock menu and window lists
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("HiddenWindow") ?? false }) {
                    window.isExcludedFromWindowsMenu = true
                    window.title = ""  // Remove title to ensure it doesn't show anywhere
                }
            }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
}