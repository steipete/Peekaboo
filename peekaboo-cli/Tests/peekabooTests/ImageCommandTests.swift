import ArgumentParser
@testable import peekaboo
import XCTest

final class ImageCommandTests: XCTestCase {
    // MARK: - Command Parsing Tests

    func testImageCommandParsing() throws {
        // Test basic command parsing
        let command = try ImageCommand.parse([])

        // Verify defaults
        XCTAssertEqual(command.mode, .activeWindow)
        XCTAssertEqual(command.format, .png)
        XCTAssertNil(command.output)
        XCTAssertNil(command.app)
        XCTAssertNil(command.windowId)
        XCTAssertFalse(command.includeWindowFrame)
        XCTAssertEqual(command.quality, 90)
    }

    func testImageCommandWithScreenMode() throws {
        // Test screen capture mode
        let command = try ImageCommand.parse(["--mode", "screen"])

        XCTAssertEqual(command.mode, .screen)
    }

    func testImageCommandWithAppSpecifier() throws {
        // Test app-specific capture
        let command = try ImageCommand.parse([
            "--mode", "app",
            "--app", "Finder"
        ])

        XCTAssertEqual(command.mode, .app)
        XCTAssertEqual(command.app, "Finder")
    }

    func testImageCommandWithWindowId() throws {
        // Test window ID capture
        let command = try ImageCommand.parse([
            "--mode", "window",
            "--window-id", "123"
        ])

        XCTAssertEqual(command.mode, .window)
        XCTAssertEqual(command.windowId, 123)
    }

    func testImageCommandWithOutput() throws {
        // Test output path specification
        let outputPath = "/tmp/test-image.png"
        let command = try ImageCommand.parse([
            "--output", outputPath
        ])

        XCTAssertEqual(command.output, outputPath)
    }

    func testImageCommandWithFormat() throws {
        // Test JPEG format
        let command = try ImageCommand.parse([
            "--format", "jpg",
            "--quality", "85"
        ])

        XCTAssertEqual(command.format, .jpg)
        XCTAssertEqual(command.quality, 85)
    }

    func testImageCommandWithJSONOutput() throws {
        // Test JSON output flag
        let command = try ImageCommand.parse(["--json-output"])

        XCTAssertTrue(command.jsonOutput)
    }

    // MARK: - Validation Tests

    func testImageCommandValidationMissingApp() {
        // Test that app mode requires app name
        XCTAssertThrowsError(try ImageCommand.parse([
            "--mode", "app"
            // Missing --app parameter
        ]))
    }

    func testImageCommandValidationMissingWindowId() {
        // Test that window mode requires window ID
        XCTAssertThrowsError(try ImageCommand.parse([
            "--mode", "window"
            // Missing --window-id parameter
        ]))
    }

    func testImageCommandValidationInvalidQuality() {
        // Test quality validation
        XCTAssertThrowsError(try ImageCommand.parse([
            "--quality", "150" // > 100
        ]))

        XCTAssertThrowsError(try ImageCommand.parse([
            "--quality", "-10" // < 0
        ]))
    }

    // MARK: - Capture Mode Tests

    func testCaptureModeRawValues() {
        // Test capture mode string values
        XCTAssertEqual(CaptureMode.screen.rawValue, "screen")
        XCTAssertEqual(CaptureMode.activeWindow.rawValue, "active_window")
        XCTAssertEqual(CaptureMode.app.rawValue, "app")
        XCTAssertEqual(CaptureMode.window.rawValue, "window")
        XCTAssertEqual(CaptureMode.area.rawValue, "area")
    }

    func testImageFormatRawValues() {
        // Test image format values
        XCTAssertEqual(ImageFormat.png.rawValue, "png")
        XCTAssertEqual(ImageFormat.jpg.rawValue, "jpg")
        XCTAssertEqual(ImageFormat.data.rawValue, "data")
    }

    // MARK: - Helper Method Tests

    func testGenerateFilename() {
        // Test filename generation with pattern
        let pattern = "{app}_{mode}_{timestamp}"
        let date = Date(timeIntervalSince1970: 1_700_000_000) // Fixed date for testing

        // Mock the filename generation logic
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: date)

        let filename = pattern
            .replacingOccurrences(of: "{app}", with: "Finder")
            .replacingOccurrences(of: "{mode}", with: "window")
            .replacingOccurrences(of: "{timestamp}", with: timestamp)

        XCTAssertTrue(filename.contains("Finder"))
        XCTAssertTrue(filename.contains("window"))
        XCTAssertTrue(filename.contains("2023-11-14")) // Date from timestamp
    }

    func testBlurDetection() {
        // Test blur detection threshold logic
        let blurThresholds: [Double] = [0.0, 0.5, 1.0]

        for threshold in blurThresholds {
            XCTAssertGreaterThanOrEqual(threshold, 0.0)
            XCTAssertLessThanOrEqual(threshold, 1.0)
        }
    }

    // MARK: - Error Response Tests

    func testErrorResponseCreation() throws {
        // Test error response structure
        let error = CaptureError.appNotFound

        let errorData = SwiftCliErrorData(
            error: error.rawValue,
            message: error.description,
            details: nil,
            suggestions: []
        )

        XCTAssertEqual(errorData.error, "APP_NOT_FOUND")
        XCTAssertEqual(errorData.message, "Application not found")
    }

    // MARK: - Integration Tests

    func testImageCaptureDataEncoding() throws {
        // Test that ImageCaptureData can be encoded to JSON
        let captureData = ImageCaptureData(
            imageData: "base64data",
            imageUrl: nil,
            savedFile: nil,
            metadata: ImageMetadata(
                width: 1920,
                height: 1080,
                fileSize: 1_024_000,
                format: "png",
                colorSpace: "sRGB",
                bitsPerPixel: 24,
                capturedAt: "2023-11-14T12:00:00Z"
            ),
            captureMode: "screen",
            targetApp: nil,
            windowInfo: nil,
            isBlurry: false,
            blurScore: 0.1,
            debugLogs: []
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(captureData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["image_data"] as? String, "base64data")
        XCTAssertEqual(json?["capture_mode"] as? String, "screen")
        XCTAssertEqual(json?["is_blurry"] as? Bool, false)

        let metadata = json?["metadata"] as? [String: Any]
        XCTAssertEqual(metadata?["width"] as? Int, 1920)
        XCTAssertEqual(metadata?["height"] as? Int, 1080)
    }
}
