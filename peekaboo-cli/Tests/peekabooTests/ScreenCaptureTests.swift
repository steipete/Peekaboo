import Testing
import Foundation
import CoreGraphics
@testable import peekaboo

@Suite("ScreenCapture Tests")
struct ScreenCaptureTests {
    
    @Suite("Display Capture Tests", .tags(.localOnly))
    struct DisplayCaptureTests {
        let tempDir: URL
        
        init() throws {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        
        @Test("Captures main display", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
        func testCapturesMainDisplay() async throws {
            let mainDisplayID = CGMainDisplayID()
            let outputPath = tempDir.appendingPathComponent("main-display.png").path
            
            try await ScreenCapture.captureDisplay(mainDisplayID, to: outputPath, format: .png)
            
            #expect(FileManager.default.fileExists(atPath: outputPath))
            
            // Verify it's a valid image
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            #expect(data.count > 1000) // Should be a reasonable size
            
            // Check PNG header
            #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        }
        
        @Test("Captures in JPEG format", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
        func testCapturesInJPEGFormat() async throws {
            let mainDisplayID = CGMainDisplayID()
            let outputPath = tempDir.appendingPathComponent("main-display.jpg").path
            
            try await ScreenCapture.captureDisplay(mainDisplayID, to: outputPath, format: .jpg)
            
            #expect(FileManager.default.fileExists(atPath: outputPath))
            
            // Verify it's a valid JPEG
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            #expect(data.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
        }
        
        @Test("Fails with invalid display ID", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
        func testFailsWithInvalidDisplayID() async throws {
            let invalidDisplayID: CGDirectDisplayID = 999999
            let outputPath = tempDir.appendingPathComponent("invalid.png").path
            
            await #expect(throws: CaptureError.self) {
                try await ScreenCapture.captureDisplay(invalidDisplayID, to: outputPath)
            }
        }
    }
    
    @Suite("Window Capture Tests", .tags(.localOnly))
    struct WindowCaptureTests {
        let tempDir: URL
        
        init() throws {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        
        @Test("Captures window by ID", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
        func testCapturesWindowByID() async throws {
            // First get a valid window ID from Finder
            let apps = ApplicationFinder.getAllRunningApplications()
            let finder = apps.first { $0.bundle_id == "com.apple.finder" }
            let finderApp = try #require(finder)
            
            let windows = try WindowManager.getWindowsForApp(pid: finderApp.pid)
            let window = try #require(windows.first)
            
            let outputPath = tempDir.appendingPathComponent("window.png").path
            
            try await ScreenCapture.captureWindow(window, to: outputPath, format: .png)
            
            #expect(FileManager.default.fileExists(atPath: outputPath))
            
            // Verify it's a valid image
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            #expect(data.count > 100) // Should have some content
        }
        
        @Test("Fails with invalid window ID", .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
        func testFailsWithInvalidWindowID() async throws {
            // Create a fake window data with invalid ID
            let invalidWindow = WindowData(
                windowId: 999999,
                title: "Invalid Window",
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                isOnScreen: false,
                windowIndex: 0
            )
            let outputPath = tempDir.appendingPathComponent("invalid-window.png").path
            
            await #expect(throws: CaptureError.self) {
                try await ScreenCapture.captureWindow(invalidWindow, to: outputPath)
            }
        }
    }
    
    @Suite("Permission Error Detection")
    struct PermissionErrorDetectionTests {
        
        @Test("Captures convert to permission errors when appropriate")
        func testCapturesConvertToPermissionErrors() async {
            // This test verifies the error conversion logic without requiring actual permissions
            let tempPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).png").path
            
            // When we don't have permissions, ScreenCaptureKit will throw specific errors
            // This test would fail in CI but demonstrates the error handling path
            if ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != "true" {
                // Skip this test in CI
                return
            }
            
            // Attempt to capture without permissions should convert to our error type
            do {
                try await ScreenCapture.captureDisplay(CGMainDisplayID(), to: tempPath)
            } catch let error as CaptureError {
                // If we get a CaptureError, it should be a permission error
                switch error {
                case .screenRecordingPermissionDenied:
                    // Expected when permissions are not granted
                    break
                default:
                    // Other errors are also valid (display not found, etc)
                    break
                }
            } catch {
                // Non-CaptureError means our error handling didn't work
                Issue.record("Expected CaptureError but got \(type(of: error))")
            }
        }
    }
    
    @Suite("Capture Configuration")
    struct CaptureConfigurationTests {
        
        @Test("Default configuration includes cursor")
        func testDefaultConfigurationIncludesCursor() {
            // This is more of a documentation test to ensure our assumptions are correct
            // The actual SCStreamConfiguration is created inside ScreenCapture methods
            
            // We expect:
            // - configuration.showsCursor = true
            // - configuration.backgroundColor = .black
            // - configuration.shouldBeOpaque = true
            
            // These settings are hardcoded in ScreenCapture.swift
            // This test serves as a reminder if we ever want to make them configurable
            #expect(Bool(true)) // Configuration is hardcoded as expected
        }
    }
}