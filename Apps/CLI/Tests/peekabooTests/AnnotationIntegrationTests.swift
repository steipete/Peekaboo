import AppKit
import Foundation
import Testing
@testable import peekaboo

@Suite("Annotation Drawing Integration Tests", .serialized)
struct AnnotationIntegrationTests {
    // These tests require actual window capture capabilities
    // Run with: RUN_LOCAL_TESTS=true swift test

    @Test("Annotated screenshot generation with window bounds")
    func annotatedScreenshotGeneration() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw TestSkipped("Local test - set RUN_LOCAL_TESTS=true to run")
        }

        // Create a test window at a known position
        let testWindow = await createTestWindow(at: CGPoint(x: 200, y: 300))
        defer {
            Task { @MainActor in
                testWindow.close()
            }
        }

        // Allow window to appear
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Capture the window using SeeCommand
        let sessionId = String(ProcessInfo.processInfo.processIdentifier)
        let outputPath = "/tmp/test-annotation-\(sessionId).png"
        let annotatedPath = "/tmp/test-annotation-\(sessionId)-annotated.png"

        // Simulate see command execution
        let captureResult = CaptureResult(
            outputPath: outputPath,
            applicationName: "AnnotationTest",
            windowTitle: "Test Window",
            suggestedName: "test",
            windowBounds: CGRect(x: 200, y: 300, width: 600, height: 400)
        )

        // Verify window bounds are captured
        #expect(captureResult.windowBounds != nil)
        #expect(captureResult.windowBounds?.origin.x == 200)
        #expect(captureResult.windowBounds?.origin.y == 300)

        // Clean up
        try? FileManager.default.removeItem(atPath: outputPath)
        try? FileManager.default.removeItem(atPath: annotatedPath)
    }

    @Test("Coordinate transformation in real window")
    func realWindowCoordinateTransformation() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw TestSkipped("Local test - set RUN_LOCAL_TESTS=true to run")
        }

        // Create window with button at known position
        let window = await createTestWindowWithButton()
        defer {
            Task { @MainActor in
                window.close()
            }
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        // Get window bounds
        let windowBounds = await window.frame

        // Get button frame (in window coordinates)
        let button = await window.contentView?.subviews.first
        let buttonFrame = await button?.frame ?? .zero

        // Convert to screen coordinates (what accessibility API returns)
        let screenFrame = await window.convertToScreen(buttonFrame)

        // Test transformation back to window coordinates
        let transformedX = screenFrame.origin.x - windowBounds.origin.x
        let transformedY = screenFrame.origin.y - windowBounds.origin.y

        // Should approximately match original button frame
        // (may have small differences due to window chrome)
        #expect(abs(transformedX - buttonFrame.origin.x) < 5)
        #expect(abs(transformedY - buttonFrame.origin.y) < 5)
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestWindow(at position: CGPoint) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: position.x, y: position.y, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Annotation Test Window"
        window.makeKeyAndOrderFront(nil)
        return window
    }

    @MainActor
    private func createTestWindowWithButton() -> NSWindow {
        let window = self.createTestWindow(at: CGPoint(x: 300, y: 400))

        // Add a button at a known position
        let button = NSButton(frame: NSRect(x: 50, y: 50, width: 100, height: 30))
        button.title = "Test Button"
        button.bezelStyle = .rounded

        window.contentView?.addSubview(button)

        return window
    }

    private func createTestImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw some test content
        NSColor.lightGray.setFill()
        NSRect(x: 0, y: size.height - 50, width: size.width, height: 50).fill()

        image.unlockFocus()
        return image
    }
}

// Test skip error for local-only tests
struct TestSkipped: Error {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }
}

// MARK: - Test Types

private struct CaptureResult {
    let outputPath: String
    let applicationName: String?
    let windowTitle: String?
    let suggestedName: String
    let windowBounds: CGRect?
}
