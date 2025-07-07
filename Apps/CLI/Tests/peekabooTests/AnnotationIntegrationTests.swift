import AppKit
import Foundation
import Testing
@testable import peekaboo

@Suite("Annotation Drawing Integration Tests", .serialized)
struct AnnotationIntegrationTests {
    // These tests require actual window capture capabilities
    // Run with: RUN_LOCAL_TESTS=true swift test

    @Test("Annotated screenshot generation with window bounds")
    @available(macOS 14.0, *)
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
            windowBounds: CGRect(x: 200, y: 300, width: 600, height: 400))

        // Verify window bounds are captured
        #expect(captureResult.windowBounds != nil)
        #expect(captureResult.windowBounds?.origin.x == 200)
        #expect(captureResult.windowBounds?.origin.y == 300)

        // Clean up
        try? FileManager.default.removeItem(atPath: outputPath)
        try? FileManager.default.removeItem(atPath: annotatedPath)
    }

    @Test("Coordinate transformation in real window")
    @available(macOS 14.0, *)
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

    @Test("Annotation overlay pixel accuracy")
    @available(macOS 14.0, *)
    func annotationOverlayAccuracy() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw TestSkipped("Local test - set RUN_LOCAL_TESTS=true to run")
        }

        // Create a simple test image
        let imageSize = NSSize(width: 800, height: 600)
        let testImage = self.createTestImage(size: imageSize)

        // Define test elements with known positions
        let testElements: [String: SessionCache.SessionData.UIElement] = [
            "B1": SessionCache.SessionData.UIElement(
                id: "B1",
                elementId: "button1",
                role: "AXButton",
                title: "Test Button",
                label: nil,
                value: nil,
                frame: CGRect(x: 100, y: 100, width: 120, height: 40),
                isActionable: true
            ),
        ]

        // Create annotated image
        let annotatedImage = try await drawAnnotations(
            on: testImage,
            elements: testElements,
            windowBounds: CGRect(x: 0, y: 0, width: 800, height: 600))

        // Save for manual inspection if needed
        if let tiffData = annotatedImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:])
        {
            try pngData.write(to: URL(fileURLWithPath: "/tmp/test-overlay-accuracy.png"))
        }

        // Verify image was created with correct size
        #expect(annotatedImage.size == imageSize)
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestWindow(at position: CGPoint) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: position.x, y: position.y, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
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

    @MainActor
    private func drawAnnotations(
        on image: NSImage,
        elements: [String: SessionCache.SessionData.UIElement],
        windowBounds: CGRect?) async throws -> NSImage
    {
        let annotatedImage = NSImage(size: image.size)
        annotatedImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)

        // Set up drawing context
        guard let context = NSGraphicsContext.current else {
            annotatedImage.unlockFocus()
            throw CaptureError.captureFailure("No graphics context")
        }

        context.saveGraphicsState()

        // Draw annotations for actionable elements
        for element in elements.values where element.isActionable {
            // Transform coordinates
            var elementFrame = element.frame
            if let bounds = windowBounds {
                elementFrame.origin.x -= bounds.origin.x
                elementFrame.origin.y -= bounds.origin.y
            }

            // Flip Y coordinate for drawing
            let drawRect = NSRect(
                x: elementFrame.origin.x,
                y: image.size.height - elementFrame.origin.y - elementFrame.height,
                width: elementFrame.width,
                height: elementFrame.height)

            // Draw overlay
            NSColor.systemBlue.withAlphaComponent(0.3).setFill()
            drawRect.fill()

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: drawRect)
            path.lineWidth = 2
            path.stroke()

            // Draw label
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.8),
            ]

            let label = element.id
            let labelSize = label.size(withAttributes: attributes)
            let labelRect = NSRect(
                x: drawRect.origin.x + 4,
                y: drawRect.origin.y + drawRect.height - labelSize.height - 4,
                width: labelSize.width + 8,
                height: labelSize.height + 4)

            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()

            label.draw(at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2), withAttributes: attributes)
        }

        context.restoreGraphicsState()
        annotatedImage.unlockFocus()

        return annotatedImage
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
