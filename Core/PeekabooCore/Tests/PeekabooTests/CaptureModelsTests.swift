import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCore

@Suite("Capture Models Tests - Current API")
struct CaptureModelsTests {
    
    @Test("CaptureMode enum values and properties")
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
        
        // Test CaseIterable conformance
        let allModes = CaptureMode.allCases
        #expect(allModes.count == 5)
        #expect(allModes.contains(.screen))
        #expect(allModes.contains(.window))
        #expect(allModes.contains(.multi))
        #expect(allModes.contains(.frontmost))
        #expect(allModes.contains(.area))
    }
    
    @Test("ImageFormat enum values and properties")
    func imageFormat() {
        // Test ImageFormat enum values
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.jpg.rawValue == "jpg")
        
        // Test ImageFormat from string
        #expect(ImageFormat(rawValue: "png") == .png)
        #expect(ImageFormat(rawValue: "jpg") == .jpg)
        #expect(ImageFormat(rawValue: "invalid") == nil)
        
        // Test CaseIterable conformance
        let allFormats = ImageFormat.allCases
        #expect(allFormats.count == 2) // png and jpg
        #expect(allFormats.contains(.png))
        #expect(allFormats.contains(.jpg))
    }
    
    @Test("CaptureFocus enum values and properties")
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
        
        // Test CaseIterable conformance
        let allFocus = CaptureFocus.allCases
        #expect(allFocus.count == 3)
        #expect(allFocus.contains(.background))
        #expect(allFocus.contains(.auto))
        #expect(allFocus.contains(.foreground))
    }
    
    @Test("SavedFile initialization and properties")
    func savedFile() {
        let testPath = "/tmp/test_screenshot.png"
        let testMimeType = "image/png"
        
        // Test full initialization
        let fullFile = SavedFile(
            path: testPath,
            item_label: "Test Screenshot",
            window_title: "Safari",
            window_id: 123,
            window_index: 0,
            mime_type: testMimeType
        )
        
        #expect(fullFile.path == testPath)
        #expect(fullFile.item_label == "Test Screenshot")
        #expect(fullFile.window_title == "Safari")
        #expect(fullFile.window_id == 123)
        #expect(fullFile.window_index == 0)
        #expect(fullFile.mime_type == testMimeType)
        
        // Test minimal initialization
        let minimalFile = SavedFile(
            path: testPath,
            mime_type: testMimeType
        )
        
        #expect(minimalFile.path == testPath)
        #expect(minimalFile.item_label == nil)
        #expect(minimalFile.window_title == nil)
        #expect(minimalFile.window_id == nil)
        #expect(minimalFile.window_index == nil)
        #expect(minimalFile.mime_type == testMimeType)
    }
    
    @Test("ImageCaptureData initialization and properties")
    func imageCaptureData() {
        let file1 = SavedFile(path: "/tmp/file1.png", mime_type: "image/png")
        let file2 = SavedFile(path: "/tmp/file2.jpg", mime_type: "image/jpeg")
        let files = [file1, file2]
        
        let captureData = ImageCaptureData(saved_files: files)
        
        #expect(captureData.saved_files.count == 2)
        #expect(captureData.saved_files[0].path == "/tmp/file1.png")
        #expect(captureData.saved_files[0].mime_type == "image/png")
        #expect(captureData.saved_files[1].path == "/tmp/file2.jpg")
        #expect(captureData.saved_files[1].mime_type == "image/jpeg")
        
        // Test empty files array
        let emptyCaptureData = ImageCaptureData(saved_files: [])
        #expect(emptyCaptureData.saved_files.isEmpty)
    }
    
    @Test("CaptureMetadata initialization and properties")
    func captureMetadata() {
        let testSize = CGSize(width: 1920, height: 1080)
        let captureTime = Date()
        
        // Test minimal initialization
        let minimalMetadata = CaptureMetadata(
            size: testSize,
            mode: .screen,
            timestamp: captureTime
        )
        
        #expect(minimalMetadata.size == testSize)
        #expect(minimalMetadata.mode == .screen)
        #expect(minimalMetadata.applicationInfo == nil)
        #expect(minimalMetadata.windowInfo == nil)
        #expect(minimalMetadata.displayInfo == nil)
        #expect(minimalMetadata.timestamp == captureTime)
        
        // Test with display info
        let displayInfo = DisplayInfo(
            index: 1,
            name: "Built-in Display",
            bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            scaleFactor: 2.0
        )
        let metadataWithDisplay = CaptureMetadata(
            size: testSize,
            mode: .screen,
            displayInfo: displayInfo,
            timestamp: captureTime
        )
        
        #expect(metadataWithDisplay.displayInfo?.index == 1)
    }
    
    @Test("DisplayInfo initialization and properties")
    func displayInfo() {
        let displayInfo = DisplayInfo(
            index: 2,
            name: "External Display",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            scaleFactor: 1.0
        )
        #expect(displayInfo.index == 2)
        #expect(displayInfo.name == "External Display")
        #expect(displayInfo.bounds.width == 1920)
        #expect(displayInfo.scaleFactor == 1.0)
        
        // Test boundary values
        let minDisplay = DisplayInfo(
            index: 0,
            name: "Primary Display",
            bounds: CGRect(x: 0, y: 0, width: 1024, height: 768),
            scaleFactor: 1.0
        )
        #expect(minDisplay.index == 0)
        
        let maxDisplay = DisplayInfo(
            index: 10,
            name: nil,
            bounds: CGRect.zero,
            scaleFactor: 2.0
        )
        #expect(maxDisplay.index == 10)
        #expect(maxDisplay.name == nil)
    }
    
    @Test("Codable conformance for enums")
    func enumCodableConformance() throws {
        // Test CaptureMode encoding/decoding
        let originalMode = CaptureMode.window
        let encodedMode = try JSONEncoder().encode(originalMode)
        let decodedMode = try JSONDecoder().decode(CaptureMode.self, from: encodedMode)
        #expect(decodedMode == originalMode)
        
        // Test ImageFormat encoding/decoding
        let originalFormat = ImageFormat.png
        let encodedFormat = try JSONEncoder().encode(originalFormat)
        let decodedFormat = try JSONDecoder().decode(ImageFormat.self, from: encodedFormat)
        #expect(decodedFormat == originalFormat)
        
        // Test CaptureFocus encoding/decoding
        let originalFocus = CaptureFocus.auto
        let encodedFocus = try JSONEncoder().encode(originalFocus)
        let decodedFocus = try JSONDecoder().decode(CaptureFocus.self, from: encodedFocus)
        #expect(decodedFocus == originalFocus)
    }
    
    @Test("Codable conformance for data structures")
    func structCodableConformance() throws {
        // Test SavedFile encoding/decoding
        let originalFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Test",
            window_title: "Window",
            window_id: 42,
            window_index: 1,
            mime_type: "image/png"
        )
        
        let encodedFile = try JSONEncoder().encode(originalFile)
        let decodedFile = try JSONDecoder().decode(SavedFile.self, from: encodedFile)
        
        #expect(decodedFile.path == originalFile.path)
        #expect(decodedFile.item_label == originalFile.item_label)
        #expect(decodedFile.window_title == originalFile.window_title)
        #expect(decodedFile.window_id == originalFile.window_id)
        #expect(decodedFile.window_index == originalFile.window_index)
        #expect(decodedFile.mime_type == originalFile.mime_type)
        
        // Test ImageCaptureData encoding/decoding
        let originalCaptureData = ImageCaptureData(saved_files: [originalFile])
        let encodedCaptureData = try JSONEncoder().encode(originalCaptureData)
        let decodedCaptureData = try JSONDecoder().decode(ImageCaptureData.self, from: encodedCaptureData)
        
        #expect(decodedCaptureData.saved_files.count == 1)
        #expect(decodedCaptureData.saved_files[0].path == originalFile.path)
    }
    
    @Test("Enum validation and edge cases")
    func enumValidation() {
        // Test all CaptureMode cases can be created from their raw values
        for mode in CaptureMode.allCases {
            let recreated = CaptureMode(rawValue: mode.rawValue)
            #expect(recreated == mode)
        }
        
        // Test all ImageFormat cases can be created from their raw values
        for format in ImageFormat.allCases {
            let recreated = ImageFormat(rawValue: format.rawValue)
            #expect(recreated == format)
        }
        
        // Test all CaptureFocus cases can be created from their raw values
        for focus in CaptureFocus.allCases {
            let recreated = CaptureFocus(rawValue: focus.rawValue)
            #expect(recreated == focus)
        }
        
        // Test invalid raw values return nil
        #expect(CaptureMode(rawValue: "") == nil)
        #expect(ImageFormat(rawValue: "invalid") == nil)
        #expect(CaptureFocus(rawValue: "unknown") == nil)
    }
    
    @Test("MIME type consistency")
    func mimeTypeConsistency() {
        // Test that MIME types match expected patterns
        let pngFile = SavedFile(path: "/tmp/test.png", mime_type: "image/png")
        let jpgFile = SavedFile(path: "/tmp/test.jpg", mime_type: "image/jpeg")
        
        #expect(pngFile.mime_type == "image/png")
        #expect(jpgFile.mime_type == "image/jpeg")
        
        // Test MIME type format validation
        #expect(pngFile.mime_type.contains("/"))
        #expect(jpgFile.mime_type.contains("/"))
        #expect(pngFile.mime_type.hasPrefix("image/"))
        #expect(jpgFile.mime_type.hasPrefix("image/"))
    }
}