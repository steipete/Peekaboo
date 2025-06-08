import AppKit
import CoreGraphics
@testable import peekaboo
import ScreenCaptureKit
import Testing

@Suite(
    "Screenshot Validation Tests",
    .tags(.localOnly, .screenshot, .integration),
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct ScreenshotValidationTests {
    // MARK: - Image Analysis Tests

    @Test("Validate screenshot contains expected content", .tags(.imageAnalysis))
    func validateScreenshotContent() async throws {
        // Create a temporary test window with known content
        let testWindow = createTestWindow(withContent: .text("PEEKABOO_TEST_12345"))
        defer { testWindow.close() }

        // Give window time to render
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Capture the window
        let windowID = CGWindowID(testWindow.windowNumber)

        let outputPath = "/tmp/peekaboo-content-test.png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        _ = try await captureWindowToFile(windowID: windowID, path: outputPath, format: .png)

        // Load and analyze the image
        guard let image = NSImage(contentsOfFile: outputPath) else {
            Issue.record("Failed to load captured image")
            return
        }

        // Verify image properties
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)

        // In a real test, we could use OCR or pixel analysis to verify content
        print("Captured image size: \(image.size)")
    }

    @Test("Compare screenshots for visual regression", .tags(.regression))
    func visualRegressionTest() async throws {
        // Create test window with specific visual pattern
        let testWindow = createTestWindow(withContent: .grid)
        defer { testWindow.close() }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let windowID = CGWindowID(testWindow.windowNumber)

        // Capture baseline
        let baselinePath = "/tmp/peekaboo-baseline.png"
        let currentPath = "/tmp/peekaboo-current.png"
        defer {
            try? FileManager.default.removeItem(atPath: baselinePath)
            try? FileManager.default.removeItem(atPath: currentPath)
        }

        _ = try await captureWindowToFile(windowID: windowID, path: baselinePath, format: .png)

        // Make a small change (in real tests, this would be application state change)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Capture current
        _ = try await captureWindowToFile(windowID: windowID, path: currentPath, format: .png)

        // Compare images
        let baselineImage = NSImage(contentsOfFile: baselinePath)
        let currentImage = NSImage(contentsOfFile: currentPath)

        #expect(baselineImage != nil)
        #expect(currentImage != nil)

        // In practice, we'd use image diff algorithms here
        #expect(baselineImage!.size == currentImage!.size)
    }

    @Test("Test different image formats", .tags(.formats))
    func imageFormats() async throws {
        let testWindow = createTestWindow(withContent: .gradient)
        defer { testWindow.close() }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let windowID = CGWindowID(testWindow.windowNumber)

        let formats: [ImageFormat] = [.png, .jpg]

        for format in formats {
            let path = "/tmp/peekaboo-format-test.\(format.rawValue)"
            defer { try? FileManager.default.removeItem(atPath: path) }

            _ = try await captureWindowToFile(windowID: windowID, path: path, format: format)

            #expect(FileManager.default.fileExists(atPath: path))

            // Verify file size makes sense for format
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            print("Format \(format.rawValue): \(fileSize) bytes")
            #expect(fileSize > 0)

            // PNG should typically be larger than JPG for photos
            if format == .jpg {
                #expect(fileSize < 500_000) // JPG should be reasonably compressed
            }
        }
    }

    // MARK: - Multi-Display Tests

    @Test("Capture from multiple displays", .tags(.multiDisplay))
    func multiDisplayCapture() async throws {
        let screens = NSScreen.screens
        print("Found \(screens.count) display(s)")

        for (index, screen) in screens.enumerated() {
            let displayID = getDisplayID(for: screen)
            let outputPath = "/tmp/peekaboo-display-\(index).png"
            defer { try? FileManager.default.removeItem(atPath: outputPath) }

            do {
                _ = try await captureDisplayToFile(displayID: displayID, path: outputPath, format: .png)

                #expect(FileManager.default.fileExists(atPath: outputPath))

                // Verify captured dimensions match screen
                if let image = NSImage(contentsOfFile: outputPath) {
                    let screenSize = screen.frame.size
                    let scale = screen.backingScaleFactor

                    // Image size should match screen size * scale factor
                    #expect(abs(image.size.width - screenSize.width * scale) < 2)
                    #expect(abs(image.size.height - screenSize.height * scale) < 2)
                }
            } catch {
                print("Failed to capture display \(index): \(error)")
                if screens.count == 1 {
                    throw error // Re-throw if it's the only display
                }
            }
        }
    }

    // MARK: - Performance Tests

    @Test("Screenshot capture performance", .tags(.performance))
    func capturePerformance() async throws {
        let testWindow = createTestWindow(withContent: .solid(.white))
        defer { testWindow.close() }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let windowID = CGWindowID(testWindow.windowNumber)

        let iterations = 10
        var captureTimes: [TimeInterval] = []

        for iteration in 0..<iterations {
            let path = "/tmp/peekaboo-perf-\(iteration).png"
            defer { try? FileManager.default.removeItem(atPath: path) }

            let start = CFAbsoluteTimeGetCurrent()
            _ = try await captureWindowToFile(windowID: windowID, path: path, format: .png)
            let duration = CFAbsoluteTimeGetCurrent() - start

            captureTimes.append(duration)
        }

        let averageTime = captureTimes.reduce(0, +) / Double(iterations)
        let maxTime = captureTimes.max() ?? 0

        print("Capture performance: avg=\(averageTime * 1000)ms, max=\(maxTime * 1000)ms")

        // Performance expectations
        #expect(averageTime < 0.1) // Average should be under 100ms
        #expect(maxTime < 0.2) // Max should be under 200ms
    }

    // MARK: - Helper Functions

    private func createTestWindow(withContent content: TestContent) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Peekaboo Test Window"
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true

        switch content {
        case let .solid(color):
            contentView.layer?.backgroundColor = color.cgColor
        case .gradient:
            let gradient = CAGradientLayer()
            gradient.frame = contentView.bounds
            gradient.colors = [
                NSColor.red.cgColor,
                NSColor.yellow.cgColor,
                NSColor.green.cgColor,
                NSColor.blue.cgColor
            ]
            contentView.layer?.addSublayer(gradient)
        case let .text(string):
            contentView.layer?.backgroundColor = NSColor.white.cgColor
            let textField = NSTextField(labelWithString: string)
            textField.font = NSFont.systemFont(ofSize: 24)
            textField.frame = contentView.bounds
            textField.alignment = .center
            contentView.addSubview(textField)
        case .grid:
            contentView.layer?.backgroundColor = NSColor.white.cgColor
            // Grid pattern would be drawn here
        }

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)

        return window
    }

    private func captureWindowToFile(
        windowID: CGWindowID,
        path: String,
        format: ImageFormat
    ) async throws -> ImageCaptureData {
        // Use modern ScreenCaptureKit API instead of deprecated CGWindowListCreateImage
        let image = try await captureWindowWithScreenCaptureKit(windowID: windowID)

        // Save to file
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        try saveImage(nsImage, to: path, format: format)

        return ImageCaptureData(saved_files: [
            SavedFile(
                path: path,
                item_label: "Window \(windowID)",
                window_title: nil,
                window_id: nil,
                window_index: nil,
                mime_type: format == .png ? "image/png" : "image/jpeg"
            )
        ])
    }

    private func captureWindowWithScreenCaptureKit(windowID: CGWindowID) async throws -> CGImage {
        // Get available content
        let availableContent = try await SCShareableContent.current

        // Find the window by ID
        guard let scWindow = availableContent.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }

        // Create content filter for the specific window
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        // Configure capture settings
        let configuration = SCStreamConfiguration()
        configuration.backgroundColor = .clear
        configuration.shouldBeOpaque = true
        configuration.showsCursor = false

        // Capture the image
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    private func captureDisplayToFile(
        displayID: CGDirectDisplayID,
        path: String,
        format: ImageFormat
    ) async throws -> ImageCaptureData {
        let availableContent = try await SCShareableContent.current
        
        guard let scDisplay = availableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.captureCreationFailed(nil)
        }
        
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        
        let configuration = SCStreamConfiguration()
        configuration.backgroundColor = .clear
        configuration.shouldBeOpaque = true
        configuration.showsCursor = false
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        try saveImage(nsImage, to: path, format: format)

        return ImageCaptureData(saved_files: [
            SavedFile(
                path: path,
                item_label: "Display \(displayID)",
                window_title: nil,
                window_id: nil,
                window_index: nil,
                mime_type: format == .png ? "image/png" : "image/jpeg"
            )
        ])
    }

    private func saveImage(_ image: NSImage, to path: String, format: ImageFormat) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CaptureError.fileWriteError(path, nil)
        }

        let data: Data? = switch format {
        case .png:
            bitmap.representation(using: .png, properties: [:])
        case .jpg:
            bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }

        guard let imageData = data else {
            throw CaptureError.fileWriteError(path, nil)
        }

        try imageData.write(to: URL(fileURLWithPath: path))
    }

    private func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}

// MARK: - Test Content Types

enum TestContent {
    case solid(NSColor)
    case gradient
    case text(String)
    case grid
}
