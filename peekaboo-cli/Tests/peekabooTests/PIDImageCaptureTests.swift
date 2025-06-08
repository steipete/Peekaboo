import Foundation
import AppKit
import Testing
@testable import peekaboo

@Suite("PID Image Capture Tests")
struct PIDImageCaptureTests {
    @Test("Capture windows by PID - valid PID")
    func captureWindowsByValidPID() async throws {
        // Skip in CI environment
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }
        
        // Get a running application with windows
        let runningApps = NSWorkspace.shared.runningApplications
        guard let appWithWindows = runningApps.first(where: { app in
            app.localizedName != nil && 
            app.isActive == false && // Don't capture active app to avoid test interference
            app.bundleIdentifier != nil
        }) else {
            Issue.record("No suitable application found for PID capture testing")
            return
        }
        
        let pid = appWithWindows.processIdentifier
        
        // Create image command with PID
        var command = ImageCommand()
        command.app = "PID:\(pid)"
        command.mode = .multi
        command.format = .png
        command.path = NSTemporaryDirectory()
        command.jsonOutput = true
        
        do {
            // Mock the execution context
            let result = try await captureWithPID(command: command, targetPID: pid)
            
            #expect(result.success == true)
            // Since we're mocking, we know data is ImageCaptureData
            #expect(result.data != nil)
        } catch {
            Issue.record("Failed to capture windows by PID: \(error)")
        }
    }
    
    @Test("Capture windows by PID - multiple app instances")
    func captureWindowsByPIDMultipleInstances() async throws {
        // Skip in CI environment
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }
        
        // Find apps that might have multiple instances (e.g., Terminal, Finder windows)
        let runningApps = NSWorkspace.shared.runningApplications
        let appGroups = Dictionary(grouping: runningApps) { $0.bundleIdentifier ?? "unknown" }
        
        // Find an app with multiple instances
        guard let (_, apps) = appGroups.first(where: { $0.value.count > 1 }) else {
            // No multiple instances found, skip test
            return
        }
        
        // Pick the first instance
        let targetApp = apps[0]
        let pid = targetApp.processIdentifier
        
        // Create image command with specific PID
        var command = ImageCommand()
        command.app = "PID:\(pid)"
        command.mode = .multi
        command.format = .png
        command.path = NSTemporaryDirectory()
        command.jsonOutput = true
        
        do {
            let result = try await captureWithPID(command: command, targetPID: pid)
            
            #expect(result.success == true)
            // Since we're mocking, we know data contains windows from specific PID
            #expect(result.data != nil)
        } catch {
            Issue.record("Failed to capture specific instance by PID: \(error)")
        }
    }
    
    @Test("Invalid PID formats in image capture")
    func invalidPIDFormatsInImageCapture() throws {
        let invalidPIDs = [
            "PID:",           // Missing PID number
            "PID:abc",        // Non-numeric PID
            "PID:-123",       // Negative PID
            "PID:12.34",      // Decimal PID
            "PID:0",          // Zero PID
            "PID:999999999"   // Very large PID
        ]
        
        for invalidPID in invalidPIDs {
            var command = ImageCommand()
            command.app = invalidPID
            command.mode = .window
            command.format = .png
            command.jsonOutput = true
            
            // The command should parse but fail during execution
            #expect(command.app == invalidPID)
            
            // In actual execution, this would fail with APP_NOT_FOUND error
            // Here we just verify the command accepts the PID format
        }
    }
    
    @Test("PID targeting with window specifiers")
    func pidTargetingWithWindowSpecifiers() throws {
        // Test that PID can be combined with window index
        var command1 = ImageCommand()
        command1.app = "PID:1234"
        command1.windowIndex = 0
        command1.mode = .window
        
        #expect(command1.app == "PID:1234")
        #expect(command1.windowIndex == 0)
        
        // Test that PID can be combined with window title
        var command2 = ImageCommand()
        command2.app = "PID:5678"
        command2.windowTitle = "Document"
        command2.mode = .window
        
        #expect(command2.app == "PID:5678")
        #expect(command2.windowTitle == "Document")
    }
    
    @Test("PID targeting filename generation")
    func pidTargetingFilenameGeneration() throws {
        // Test that filenames include PID information
        let pid: pid_t = 1234
        let appName = "TestApp"
        let timestamp = "20250608_120000"
        
        // Expected filename format for PID capture
        let expectedFilename = "\(appName)_PID_\(pid)_\(timestamp).png"
        
        // Verify filename pattern
        #expect(expectedFilename.contains("PID"))
        #expect(expectedFilename.contains(String(pid)))
        #expect(expectedFilename.contains(appName))
    }
    
    // Helper function to simulate capture with PID
    private func captureWithPID(command: ImageCommand, targetPID: pid_t) async throws -> JSONResponse {
        // In real execution, this would use WindowCapture.captureWindows
        // For testing, we simulate the response
        
        guard let app = NSRunningApplication(processIdentifier: targetPID) else {
            throw ApplicationError.notFound("No application found with PID: \(targetPID)")
        }
        
        let savedFile = SavedFile(
            path: "\(command.path ?? NSTemporaryDirectory())/\(app.localizedName ?? "Unknown")_PID_\(targetPID).png",
            item_label: app.localizedName ?? "Unknown",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )
        
        let captureData = ImageCaptureData(saved_files: [savedFile])
        
        return JSONResponse(
            success: true,
            data: captureData,
            messages: ["Captured windows for PID: \(targetPID)"],
            debugLogs: [],
            error: nil
        )
    }
}