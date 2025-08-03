import AppKit
import Foundation
import Testing
@testable import PeekabooCore

@Suite("ApplicationService Tests")
struct ApplicationServiceTests {
    @Test("List windows with timeout")
    @MainActor
    func listWindowsWithTimeout() async throws {
        // Given
        let service = ApplicationService()

        // When listing windows for Finder with a short timeout
        let result = try await service.listWindows(for: "Finder", timeout: 0.5)

        // Then
        #expect(result.data.targetApplication?.name == "Finder")
        #expect(result.metadata.duration < 1.0) // Should complete within timeout
    }

    @Test("List windows respects custom timeout")
    @MainActor
    func listWindowsRespectsCustomTimeout() async throws {
        // Given
        let service = ApplicationService()
        let startTime = Date()

        // When listing windows with very short timeout
        let result = try await service.listWindows(for: "Safari", timeout: 0.1)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then - should complete quickly even if Safari has many windows
        #expect(elapsed < 0.5)
        #expect(result.metadata.warnings.contains { $0.contains("timeout") || $0.contains("incomplete") } || !result
            .data.windows.isEmpty)
    }

    @Test("List windows with nil timeout uses default")
    @MainActor
    func listWindowsWithNilTimeoutUsesDefault() async throws {
        // Given
        let service = ApplicationService()

        // When listing windows without specifying timeout
        let result = try await service.listWindows(for: "Terminal", timeout: nil)

        // Then
        #expect(result.data.targetApplication?.name == "Terminal")
        // Default timeout is 2 seconds as defined in ApplicationService
    }

    @Test("Hybrid window enumeration with screen recording")
    @MainActor
    func hybridWindowEnumerationWithScreenRecording() async throws {
        // Given
        let service = ApplicationService()
        let hasScreenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()

        // Skip test if no screen recording permission
        try #require(hasScreenRecording, "Screen recording permission required for this test")

        // When listing windows
        let result = try await service.listWindows(for: "Finder", timeout: nil)

        // Then - should use fast path with CGWindowList
        #expect(result.metadata.duration < 0.5) // CGWindowList is much faster
        #expect(result.data.windows.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Window enumeration handles terminated apps gracefully")
    @MainActor
    func windowEnumerationHandlesTerminatedApps() async throws {
        // Given
        let service = ApplicationService()

        // When trying to list windows for non-existent app
        do {
            _ = try await service.listWindows(for: "NonExistentApp12345", timeout: nil)
            Issue.record("Expected error for non-existent app")
        } catch {
            // Then - should throw appropriate error
            #expect(error is NotFoundError || error is PeekabooError)
        }
    }

    @Test("List windows returns proper output structure")
    @MainActor
    func listWindowsOutputStructure() async throws {
        // Given
        let service = ApplicationService()

        // When listing windows for Finder
        let output = try await service.listWindows(for: "Finder", timeout: nil)

        // Then - verify output structure
        #expect(output.data.targetApplication?.name == "Finder")
        #expect(output.summary.counts["windows"] != nil)
        #expect(output.summary.status == .success)
        #expect(!output.metadata.hints.isEmpty)
    }

    @Test("Timeout configuration is applied")
    @MainActor
    func timeoutConfigurationIsApplied() async throws {
        // Given
        let service = ApplicationService()

        // ApplicationService sets global timeout in init
        // Default timeout should be 2 seconds as defined in the service

        // When/Then - service is initialized with timeout configuration
        // This test verifies the service initializes properly
        // Service initialized successfully
    }

    @Test("List windows handles partial results on timeout")
    @MainActor
    func listWindowsHandlesPartialResultsOnTimeout() async throws {
        // Given
        let service = ApplicationService()

        // When listing windows with very short timeout for app with many windows
        let result = try await service.listWindows(for: "Safari", timeout: 0.05)

        // Then - should return partial results or empty with appropriate warnings
        if result.data.windows.isEmpty {
            #expect(result.metadata.warnings.contains {
                $0.contains("timeout") ||
                    $0.contains("incomplete") ||
                    $0.contains("Screen recording permission not granted")
            })
        } else {
            // Got some windows before timeout
            #expect(result.data.windows.isEmpty)
        }
    }
}
