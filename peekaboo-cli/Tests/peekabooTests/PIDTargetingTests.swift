import Foundation
import AppKit
import Testing
@testable import peekaboo

@Suite("PID Targeting Tests")
struct PIDTargetingTests {
    @Test("Find application by valid PID")
    func findByValidPID() throws {
        // Skip in CI environment
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }
        
        // Get any running application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let testApp = runningApps.first(where: { $0.localizedName != nil }) else {
            Issue.record("No running applications found for testing")
            return
        }
        
        let pid = testApp.processIdentifier
        let identifier = "PID:\(pid)"
        
        do {
            let foundApp = try ApplicationFinder.findApplication(identifier: identifier)
            #expect(foundApp.processIdentifier == pid)
            #expect(foundApp.bundleIdentifier == testApp.bundleIdentifier)
        } catch {
            Issue.record("Failed to find application by PID: \(error)")
        }
    }
    
    @Test("Invalid PID format throws error")
    func invalidPIDFormat() throws {
        // Test various invalid PID formats
        let invalidPIDs = [
            "PID:",           // Missing PID number
            "PID:abc",        // Non-numeric PID
            "PID:-123",       // Negative PID
            "PID:12.34",      // Decimal PID
            "PID:999999999"   // Very large PID (likely non-existent)
        ]
        
        for invalidPID in invalidPIDs {
            do {
                _ = try ApplicationFinder.findApplication(identifier: invalidPID)
                Issue.record("Expected error for invalid PID: \(invalidPID)")
            } catch {
                // Expected error
                #expect(error is ApplicationError)
            }
        }
    }
    
    @Test("Non-existent PID throws notFound error")
    func nonExistentPID() throws {
        // Use a very high PID number that's unlikely to exist
        let identifier = "PID:99999"
        
        do {
            _ = try ApplicationFinder.findApplication(identifier: identifier)
            Issue.record("Expected error for non-existent PID")
        } catch let error as ApplicationError {
            if case .notFound(let message) = error {
                #expect(message.contains("No application found with PID: 99999"))
            } else {
                Issue.record("Expected notFound error, got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}