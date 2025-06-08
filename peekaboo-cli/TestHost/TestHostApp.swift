import SwiftUI
import AppKit

@main
struct TestHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
                .frame(width: 600, height: 400)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultSize(width: 600, height: 400)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make sure the app appears in foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Set activation policy to regular app
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}