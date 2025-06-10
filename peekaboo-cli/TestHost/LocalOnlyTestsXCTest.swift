import AppKit
import Foundation
@testable import peekaboo
import XCTest

// MARK: - Local Only Tests for XCTest

class LocalIntegrationTests: XCTestCase {
    // Test host app details
    static let testHostBundleId = "me.steipete.PeekabooTestHost"
    static let testHostAppName = "PeekabooTestHost"
    static let testWindowTitle = "Peekaboo Test Host"
    
    override class func setUp() {
        super.setUp()
        // Only run if environment variable is set
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
    }
    
    // MARK: - Actual Screenshot Tests
    
    func testCaptureTestHostWindow() async throws {
        // Find the test host app (it should already be running - this IS the test host)
        let appInfo = try ApplicationFinder.findApplication(identifier: Self.testHostAppName)
        XCTAssertTrue(
            appInfo.bundleIdentifier == Self.testHostBundleId || appInfo.bundleIdentifier?.isEmpty == true,
            "Bundle ID should match or be empty for SPM executables"
        )
        
        // Get windows for the app
        let windows = try WindowManager.getWindowsForApp(pid: appInfo.processIdentifier)
        print("Found \(windows.count) windows for test host")
        
        // Find test window
        let testWindow = windows.first { $0.name?.contains(Self.testWindowTitle) ?? false }
        XCTAssertNotNil(testWindow, "Should find test host window")
        
        guard let window = testWindow else { return }
        
        // Capture the window
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_host_window.png")
            .path
        
        let command = ImageCommand(
            mode: .window,
            path: outputPath,
            format: .png,
            app: Self.testHostAppName,
            windowIndex: 0,
            captureFocus: .background,
            jsonOutput: false
        )
        
        do {
            let data = try await command.execute()
            XCTAssertFalse(data.saved_files.isEmpty, "Should save at least one file")
            
            if let savedFile = data.saved_files.first {
                // Verify the file exists
                XCTAssertTrue(FileManager.default.fileExists(atPath: savedFile.path))
                
                // Load and verify the image
                if let image = NSImage(contentsOfFile: savedFile.path) {
                    XCTAssertGreaterThan(image.size.width, 0)
                    XCTAssertGreaterThan(image.size.height, 0)
                    print("Successfully captured window: \(image.size)")
                } else {
                    XCTFail("Failed to load captured image")
                }
                
                // Cleanup
                try? FileManager.default.removeItem(atPath: savedFile.path)
            }
        } catch {
            XCTFail("Screenshot capture failed: \(error)")
        }
    }
    
    func testCaptureScreen() async throws {
        // Check permissions first
        let permissions = PermissionsChecker.checkPermissions()
        print("Current permissions:")
        print("- Screen Recording: \(permissions.screenRecording)")
        print("- Accessibility: \(permissions.accessibility)")
        
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
        
        do {
            let data = try await command.execute()
            XCTAssertFalse(data.saved_files.isEmpty)
            
            if let savedFile = data.saved_files.first {
                XCTAssertTrue(FileManager.default.fileExists(atPath: savedFile.path))
                try? FileManager.default.removeItem(atPath: savedFile.path)
            }
        } catch {
            XCTFail("Screen capture failed: \(error)")
        }
    }
}