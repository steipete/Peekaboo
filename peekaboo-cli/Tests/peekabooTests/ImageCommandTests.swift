import ArgumentParser
@testable import peekaboo
import XCTest

final class ImageCommandTests: XCTestCase {
    // MARK: - Command Parsing Tests

    func testImageCommandParsing() throws {
        // Test basic command parsing
        let command = try ImageCommand.parse([])

        // Verify defaults
        XCTAssertNil(command.mode)
        XCTAssertEqual(command.format, .png)
        XCTAssertNil(command.path)
        XCTAssertNil(command.app)
        XCTAssertEqual(command.captureFocus, .background)
        XCTAssertFalse(command.jsonOutput)
    }

    func testImageCommandWithScreenMode() throws {
        // Test screen capture mode
        let command = try ImageCommand.parse(["--mode", "screen"])

        XCTAssertEqual(command.mode, .screen)
    }

    func testImageCommandWithAppSpecifier() throws {
        // Test app-specific capture
        let command = try ImageCommand.parse([
            "--app", "Finder"
        ])

        XCTAssertNil(command.mode) // mode is optional
        XCTAssertEqual(command.app, "Finder")
    }

    func testImageCommandWithWindowTitle() throws {
        // Test window title capture
        let command = try ImageCommand.parse([
            "--window-title", "Documents"
        ])

        XCTAssertEqual(command.windowTitle, "Documents")
    }

    func testImageCommandWithOutput() throws {
        // Test output path specification
        let outputPath = "/tmp/test-images"
        let command = try ImageCommand.parse([
            "--path", outputPath
        ])

        XCTAssertEqual(command.path, outputPath)
    }

    func testImageCommandWithFormat() throws {
        // Test JPEG format
        let command = try ImageCommand.parse([
            "--format", "jpg"
        ])

        XCTAssertEqual(command.format, .jpg)
    }

    func testImageCommandWithJSONOutput() throws {
        // Test JSON output flag
        let command = try ImageCommand.parse(["--json-output"])

        XCTAssertTrue(command.jsonOutput)
    }

    // MARK: - Validation Tests

    func testImageCommandWithMultiMode() throws {
        // Test multi window capture mode
        let command = try ImageCommand.parse([
            "--mode", "multi",
            "--app", "Finder"
        ])

        XCTAssertEqual(command.mode, .multi)
        XCTAssertEqual(command.app, "Finder")
    }

    func testImageCommandWithScreenIndex() throws {
        // Test screen index parameter
        let command = try ImageCommand.parse([
            "--screen-index", "0"
        ])

        XCTAssertEqual(command.screenIndex, 0)
    }

    func testImageCommandWithFocus() throws {
        // Test focus options
        let command = try ImageCommand.parse([
            "--capture-focus", "foreground"
        ])

        XCTAssertEqual(command.captureFocus, .foreground)
    }

    // MARK: - Capture Mode Tests

    func testCaptureModeRawValues() {
        // Test capture mode string values
        XCTAssertEqual(CaptureMode.screen.rawValue, "screen")
        XCTAssertEqual(CaptureMode.window.rawValue, "window")
        XCTAssertEqual(CaptureMode.multi.rawValue, "multi")
    }

    func testImageFormatRawValues() {
        // Test image format values
        XCTAssertEqual(ImageFormat.png.rawValue, "png")
        XCTAssertEqual(ImageFormat.jpg.rawValue, "jpg")
    }

    // MARK: - Focus Mode Tests

    func testCaptureFocusRawValues() {
        // Test capture focus values
        XCTAssertEqual(CaptureFocus.foreground.rawValue, "foreground")
        XCTAssertEqual(CaptureFocus.background.rawValue, "background")
    }

    // MARK: - Model Tests

    func testSavedFileModel() {
        // Test SavedFile structure
        let savedFile = SavedFile(
            path: "/tmp/screenshot.png",
            item_label: "Finder Window",
            window_title: "Documents",
            window_id: 123,
            window_index: 0,
            mime_type: "image/png"
        )

        XCTAssertEqual(savedFile.path, "/tmp/screenshot.png")
        XCTAssertEqual(savedFile.item_label, "Finder Window")
        XCTAssertEqual(savedFile.window_title, "Documents")
        XCTAssertEqual(savedFile.window_id, 123)
        XCTAssertEqual(savedFile.mime_type, "image/png")
    }

    // MARK: - Integration Tests

    func testImageCaptureDataEncoding() throws {
        // Test that ImageCaptureData can be encoded to JSON
        let savedFiles = [
            SavedFile(
                path: "/tmp/screenshot1.png",
                item_label: "Finder",
                window_title: "Documents",
                window_id: 123,
                window_index: 0,
                mime_type: "image/png"
            )
        ]

        let captureData = ImageCaptureData(saved_files: savedFiles)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(captureData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        let files = json?["saved_files"] as? [[String: Any]]
        XCTAssertEqual(files?.count, 1)

        let firstFile = files?.first
        XCTAssertEqual(firstFile?["path"] as? String, "/tmp/screenshot1.png")
        XCTAssertEqual(firstFile?["mime_type"] as? String, "image/png")
    }
}
