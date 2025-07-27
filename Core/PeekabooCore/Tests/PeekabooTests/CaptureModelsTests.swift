import CoreGraphics
import Testing
@testable import PeekabooCore

@Suite("Capture Models Tests", .tags(.models, .unit))
struct CaptureModelsTests {
    // MARK: - Enum Tests

    @Test("CaptureMode enum values and parsing", .tags(.fast))
    func captureMode() {
        // Test CaptureMode enum values
        #expect(CaptureMode.screen.rawValue == "screen")
        #expect(CaptureMode.window.rawValue == "window")
        #expect(CaptureMode.multi.rawValue == "multi")
        #expect(CaptureMode.frontmost.rawValue == "frontmost")
        #expect(CaptureMode.area.rawValue == "area")

        // Test CaptureMode from string
        #expect(CaptureMode(rawValue: "screen") == .screen)
        #expect(CaptureMode(rawValue: "window") == .window)
        #expect(CaptureMode(rawValue: "multi") == .multi)
        #expect(CaptureMode(rawValue: "frontmost") == .frontmost)
        #expect(CaptureMode(rawValue: "area") == .area)
        #expect(CaptureMode(rawValue: "invalid") == nil)
    }

    @Test("ImageFormat enum values and parsing", .tags(.fast))
    func imageFormat() {
        // Test ImageFormat enum values
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.jpg.rawValue == "jpg")

        // Test ImageFormat from string
        #expect(ImageFormat(rawValue: "png") == .png)
        #expect(ImageFormat(rawValue: "jpg") == .jpg)
        #expect(ImageFormat(rawValue: "invalid") == nil)
    }

    @Test("CaptureFocus enum values and parsing", .tags(.fast))
    func captureFocus() {
        // Test CaptureFocus enum values
        #expect(CaptureFocus.background.rawValue == "background")
        #expect(CaptureFocus.auto.rawValue == "auto")
        #expect(CaptureFocus.foreground.rawValue == "foreground")

        // Test CaptureFocus from string
        #expect(CaptureFocus(rawValue: "background") == .background)
        #expect(CaptureFocus(rawValue: "auto") == .auto)
        #expect(CaptureFocus(rawValue: "foreground") == .foreground)
        #expect(CaptureFocus(rawValue: "invalid") == nil)
    }
    
    // MARK: - Model Tests
    
    @Test("SavedFile initialization and properties")
    func savedFileModel() {
        let savedFile = SavedFile(
            path: "/tmp/screenshot.png",
            item_label: "Main Window",
            window_title: "Safari",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/png"
        )
        
        #expect(savedFile.path == "/tmp/screenshot.png")
        #expect(savedFile.item_label == "Main Window")
        #expect(savedFile.window_title == "Safari")
        #expect(savedFile.window_id == 12345)
        #expect(savedFile.window_index == 0)
        #expect(savedFile.mime_type == "image/png")
    }
    
    @Test("SavedFile with nil optional properties")
    func savedFileWithNilProperties() {
        let savedFile = SavedFile(
            path: "/tmp/screenshot.png",
            mime_type: "image/png"
        )
        
        #expect(savedFile.path == "/tmp/screenshot.png")
        #expect(savedFile.item_label == nil)
        #expect(savedFile.window_title == nil)
        #expect(savedFile.window_id == nil)
        #expect(savedFile.window_index == nil)
        #expect(savedFile.mime_type == "image/png")
    }
    
    @Test("ImageCaptureData initialization")
    func imageCaptureDataModel() {
        let files = [
            SavedFile(path: "/tmp/screen1.png", mime_type: "image/png"),
            SavedFile(path: "/tmp/screen2.png", mime_type: "image/png")
        ]
        
        let captureData = ImageCaptureData(saved_files: files)
        
        #expect(captureData.saved_files.count == 2)
        #expect(captureData.saved_files[0].path == "/tmp/screen1.png")
        #expect(captureData.saved_files[1].path == "/tmp/screen2.png")
    }
}

