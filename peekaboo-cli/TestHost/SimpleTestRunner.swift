import Foundation
import AppKit
@testable import peekaboo

struct SimpleTestRunner {
    static func runPermissionTests(logger: @escaping (String) -> Void) async {
        logger("Starting permission tests...")
        
        // Test 1: Check permissions
        await testPermissions(logger: logger)
        
        // Test 2: Capture window
        await testWindowCapture(logger: logger)
        
        // Test 3: Capture screen
        await testScreenCapture(logger: logger)
        
        logger("All tests completed")
    }
    
    private static func testPermissions(logger: @escaping (String) -> Void) async {
        logger("\n📋 Test: Check Permissions")
        let permissions = PermissionsChecker.checkPermissions()
        logger("Screen Recording: \(permissions.screenRecording ? "✅" : "❌")")
        logger("Accessibility: \(permissions.accessibility ? "✅" : "❌")")
        
        if !permissions.screenRecording {
            logger("⚠️ Screen recording permission needed - dialogs should appear")
        }
    }
    
    private static func testWindowCapture(logger: @escaping (String) -> Void) async {
        logger("\n📸 Test: Window Capture")
        
        do {
            let appInfo = try ApplicationFinder.findApplication(identifier: "PeekabooTestHost")
            logger("Found app: \(appInfo.name)")
            
            let windows = try WindowManager.getWindowsForApp(pid: appInfo.processIdentifier)
            logger("Found \(windows.count) windows")
            
            if let window = windows.first {
                let outputPath = FileManager.default.temporaryDirectory
                    .appendingPathComponent("test_window.png")
                    .path
                
                let command = ImageCommand(
                    mode: .window,
                    path: outputPath,
                    format: .png,
                    app: "PeekabooTestHost",
                    windowIndex: 0,
                    captureFocus: .background,
                    jsonOutput: false
                )
                
                let data = try await command.execute()
                logger("✅ Window captured: \(data.saved_files.count) files")
                
                // Cleanup
                for file in data.saved_files {
                    try? FileManager.default.removeItem(atPath: file.path)
                }
            }
        } catch {
            logger("❌ Window capture failed: \(error)")
        }
    }
    
    private static func testScreenCapture(logger: @escaping (String) -> Void) async {
        logger("\n🖥️ Test: Screen Capture")
        
        do {
            let outputPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("test_screen.png")
                .path
            
            let command = ImageCommand(
                mode: .screen,
                path: outputPath,
                format: .png,
                screenIndex: 0,
                jsonOutput: false
            )
            
            let data = try await command.execute()
            logger("✅ Screen captured: \(data.saved_files.count) files")
            
            // Cleanup
            for file in data.saved_files {
                try? FileManager.default.removeItem(atPath: file.path)
            }
        } catch {
            logger("❌ Screen capture failed: \(error)")
        }
    }
}